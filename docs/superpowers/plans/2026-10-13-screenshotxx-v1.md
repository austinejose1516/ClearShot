# ScreenshotXX v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu-bar screenshot app (area / window / full screen) with a bottom-of-screen Quick Access card and a full annotation editor.

**Architecture:** SwiftUI views inside an AppKit shell (NSPanel for the card, NSWindow overlays for selection). ScreenCaptureKit `SCScreenshotManager` for capture. Pure logic (settings, geometry, models, layout, undo) lives in a local Swift package `Packages/ScreenshotXXCore` so it builds and tests with `swift test` in seconds; the app target depends on it.

**Tech Stack:** Swift 6 (toolchain 6.4), SwiftUI + AppKit, ScreenCaptureKit, Swift Testing, XcodeGen 2.46, KeyboardShortcuts 3.1.0.

**Spec:** `docs/superpowers/specs/2026-10-13-screenshotxx-design.md`

**Plan style note:** Tasks are written just-in-time, one phase of the spec at a time, so each brief reflects what the previous phase actually produced. Task N = Phase N of the spec.

## Global Constraints

- Minimum macOS: 26.0. SDK: macOS 27.0 (Xcode 27.0).
- Bundle id: `com.austinejose.screenshotxx`. App name: `ScreenshotXX`. `LSUIElement = true` (menu bar only).
- Swift 6 language mode, strict concurrency complete. App target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; the Core package uses nonisolated default.
- No App Sandbox. Signing: ad-hoc (`CODE_SIGN_IDENTITY = -`) until `Local.xcconfig` sets a Personal Team.
- Default hotkeys: ⌃⇧A area, ⌃⇧W window, ⌃⇧F full screen.
- Default save folder `~/Pictures/ScreenshotXX/`, default format PNG, copy to clipboard on.
- Core package must not import AppKit, SwiftUI or ScreenCaptureKit (Foundation + CoreGraphics only).
- Every `xcodebuild` call uses `-derivedDataPath build/DerivedData -quiet`.
- Commit after every task with the `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` trailer.

## Review Focus

1. Screen Recording permission revoked while the app runs → capture shows an alert, never crashes or returns a black image silently. (Owner: Task 2.)
2. Two displays with different scale factors → area selection on the second display crops the correct pixels. (Owner: Task 3.)
3. Save folder deleted or unplugged between captures → folder is recreated or an alert shows; the capture is still on the clipboard. (Owner: Task 2.)
4. Retina export → output pixel size equals source pixel size plus padding × scale; text stays sharp. (Owner: Task 8.)
5. Capture taken on a display that is later disconnected → the Quick Access card moves to the main display rather than sitting off-screen. (Owner: Task 5.)

---

### Task 1: Project skeleton — menu bar app, settings, permission onboarding, hotkeys

**Files:**
- Create: `project.yml`, `Makefile`
- Create: `Packages/ScreenshotXXCore/Package.swift`
- Create: `Packages/ScreenshotXXCore/Sources/ScreenshotXXCore/Settings/AppSettings.swift`
- Create: `Packages/ScreenshotXXCore/Sources/ScreenshotXXCore/Capture/CaptureKind.swift`
- Test: `Packages/ScreenshotXXCore/Tests/ScreenshotXXCoreTests/AppSettingsTests.swift`
- Create: `ScreenshotXX/App/ScreenshotXXApp.swift`, `ScreenshotXX/App/AppDelegate.swift`, `ScreenshotXX/App/MenuBarMenu.swift`
- Create: `ScreenshotXX/Capture/CaptureCoordinator.swift` (Phase 1 stub: logs only)
- Create: `ScreenshotXX/Services/HotkeyService.swift`, `ScreenshotXX/Services/PermissionService.swift`
- Create: `ScreenshotXX/Onboarding/PermissionOnboardingView.swift`, `ScreenshotXX/Onboarding/PermissionOnboardingWindowController.swift`
- Create: `ScreenshotXX/Settings/SettingsView.swift`

**Interfaces:**
- Produces (Core): `public enum ImageFormat: String, CaseIterable, Sendable, Codable { case png, jpeg; public var fileExtension: String }`
- Produces (Core): `@Observable public final class AppSettings { public init(defaults: UserDefaults = .standard); public static let defaultSaveFolder: URL; public var saveFolder: URL; public var imageFormat: ImageFormat; public var copiesToClipboard: Bool; public var showsCursor: Bool; public var playsSound: Bool; public var cardAutoCloseSeconds: Int /* 0 = never */ }`
- Produces (Core): `public enum CaptureKind: String, Sendable, CaseIterable { case area, window, fullScreen }`
- Produces (App): `@Observable final class CaptureCoordinator { init(settings: AppSettings); func capture(_ kind: CaptureKind) }` — Task 2 replaces the body.
- Produces (App): `enum PermissionService { static var hasScreenRecordingAccess: Bool; static func requestScreenRecordingAccess() -> Bool; static func openScreenRecordingSettings() }`
- Produces (App): `KeyboardShortcuts.Name.captureArea / .captureWindow / .captureFullScreen`
- Produces (build): `make gen | build | run | stop | core-test | check`. `make check` = `core-test` + `build`.

- [ ] **Step 1: Write the failing Core test**

`Packages/ScreenshotXXCore/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenshotXXCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ScreenshotXXCore", targets: ["ScreenshotXXCore"]),
    ],
    targets: [
        .target(name: "ScreenshotXXCore"),
        .testTarget(name: "ScreenshotXXCoreTests", dependencies: ["ScreenshotXXCore"]),
    ]
)
```

`Packages/ScreenshotXXCore/Tests/ScreenshotXXCoreTests/AppSettingsTests.swift`:

```swift
import Foundation
import Testing
@testable import ScreenshotXXCore

@Suite struct AppSettingsTests {
    /// A throwaway UserDefaults domain so tests never touch the real app settings.
    private func freshDefaults() -> (UserDefaults, cleanup: () -> Void) {
        let name = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    @Test func defaultsMatchSpec() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }
        let settings = AppSettings(defaults: defaults)

        #expect(settings.saveFolder == AppSettings.defaultSaveFolder)
        #expect(settings.saveFolder.path().hasSuffix("/Pictures/ScreenshotXX/"))
        #expect(settings.imageFormat == .png)
        #expect(settings.copiesToClipboard == true)
        #expect(settings.showsCursor == false)
        #expect(settings.playsSound == true)
        #expect(settings.cardAutoCloseSeconds == 0)
    }

    @Test func changesPersistAcrossInstances() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }

        let first = AppSettings(defaults: defaults)
        first.imageFormat = .jpeg
        first.copiesToClipboard = false
        first.showsCursor = true
        first.playsSound = false
        first.cardAutoCloseSeconds = 15
        first.saveFolder = URL(filePath: "/tmp/shots", directoryHint: .isDirectory)

        let second = AppSettings(defaults: defaults)
        #expect(second.imageFormat == .jpeg)
        #expect(second.copiesToClipboard == false)
        #expect(second.showsCursor == true)
        #expect(second.playsSound == false)
        #expect(second.cardAutoCloseSeconds == 15)
        #expect(second.saveFolder.path() == "/tmp/shots/")
    }

    @Test func jpegFilesUseJpgExtension() {
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageFormat.png.fileExtension == "png")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --package-path Packages/ScreenshotXXCore`
Expected: FAIL to compile — `cannot find 'AppSettings' in scope` (the Sources target needs at least one file; add an empty `CaptureKind.swift` first if SwiftPM complains about an empty target).

- [ ] **Step 3: Implement AppSettings and CaptureKind**

`Packages/ScreenshotXXCore/Sources/ScreenshotXXCore/Capture/CaptureKind.swift`:

```swift
public enum CaptureKind: String, Sendable, CaseIterable {
    case area, window, fullScreen
}
```

`Packages/ScreenshotXXCore/Sources/ScreenshotXXCore/Settings/AppSettings.swift`:

```swift
import Foundation
import Observation

public enum ImageFormat: String, CaseIterable, Sendable, Codable {
    case png, jpeg

    public var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        }
    }
}

/// User preferences, backed by UserDefaults. One instance per app, created by AppDelegate.
@Observable
public final class AppSettings {
    public static let defaultSaveFolder = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: "Pictures/ScreenshotXX", directoryHint: .isDirectory)

    private enum Key {
        static let saveFolder = "saveFolderPath"
        static let imageFormat = "imageFormat"
        static let copiesToClipboard = "copiesToClipboard"
        static let showsCursor = "showsCursor"
        static let playsSound = "playsSound"
        static let cardAutoCloseSeconds = "cardAutoCloseSeconds"
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var saveFolder: URL { didSet { defaults.set(saveFolder.path(), forKey: Key.saveFolder) } }
    public var imageFormat: ImageFormat { didSet { defaults.set(imageFormat.rawValue, forKey: Key.imageFormat) } }
    public var copiesToClipboard: Bool { didSet { defaults.set(copiesToClipboard, forKey: Key.copiesToClipboard) } }
    public var showsCursor: Bool { didSet { defaults.set(showsCursor, forKey: Key.showsCursor) } }
    public var playsSound: Bool { didSet { defaults.set(playsSound, forKey: Key.playsSound) } }
    /// 0 means the Quick Access card stays until closed.
    public var cardAutoCloseSeconds: Int { didSet { defaults.set(cardAutoCloseSeconds, forKey: Key.cardAutoCloseSeconds) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        saveFolder = defaults.string(forKey: Key.saveFolder)
            .map { URL(filePath: $0, directoryHint: .isDirectory) } ?? Self.defaultSaveFolder
        imageFormat = defaults.string(forKey: Key.imageFormat).flatMap(ImageFormat.init(rawValue:)) ?? .png
        copiesToClipboard = defaults.object(forKey: Key.copiesToClipboard) as? Bool ?? true
        showsCursor = defaults.object(forKey: Key.showsCursor) as? Bool ?? false
        playsSound = defaults.object(forKey: Key.playsSound) as? Bool ?? true
        cardAutoCloseSeconds = defaults.object(forKey: Key.cardAutoCloseSeconds) as? Int ?? 0
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --package-path Packages/ScreenshotXXCore`
Expected: `Test run with 3 tests passed`

- [ ] **Step 5: Project files (configuration — no test)**

`project.yml`:

```yaml
name: ScreenshotXX
options:
  bundleIdPrefix: com.austinejose
  deploymentTarget:
    macOS: "26.0"
  createIntermediateGroups: true
  disabledValidations: [missingConfigFiles]
configs:
  Debug: debug
  Release: release
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MACOSX_DEPLOYMENT_TARGET: "26.0"
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "-"
    ENABLE_HARDENED_RUNTIME: NO
    ENABLE_APP_SANDBOX: NO
packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    exactVersion: 3.1.0
  ScreenshotXXCore:
    path: Packages/ScreenshotXXCore
targets:
  ScreenshotXX:
    type: application
    platform: macOS
    sources:
      - path: ScreenshotXX
        excludes: ["Info.plist"]
    dependencies:
      - package: KeyboardShortcuts
      - package: ScreenshotXXCore
    info:
      path: ScreenshotXX/Info.plist
      properties:
        CFBundleDisplayName: ScreenshotXX
        LSUIElement: true
        LSApplicationCategoryType: public.app-category.productivity
        NSHumanReadableCopyright: "© 2026 Austine Jose"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.austinejose.screenshotxx
        PRODUCT_NAME: ScreenshotXX
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
        SWIFT_APPROACHABLE_CONCURRENCY: YES
    configFiles:
      Debug: Local.xcconfig
      Release: Local.xcconfig
schemes:
  ScreenshotXX:
    build:
      targets:
        ScreenshotXX: all
    run:
      config: Debug
```

`Makefile`:

```make
PROJECT := ScreenshotXX.xcodeproj
SCHEME  := ScreenshotXX
DERIVED := build/DerivedData
APP     := $(DERIVED)/Build/Products/Debug/ScreenshotXX.app
CORE    := Packages/ScreenshotXXCore

.PHONY: gen build run stop core-test check clean

Local.xcconfig:
	@printf '// Per-machine signing overrides (git-ignored).\n// After adding your Apple ID in Xcode > Settings > Accounts, set:\n// CODE_SIGN_STYLE = Automatic\n// CODE_SIGN_IDENTITY = Apple Development\n// DEVELOPMENT_TEAM = YOURTEAMID\n' > $@

gen: Local.xcconfig
	xcodegen generate --quiet

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) -quiet build

core-test:
	swift test --package-path $(CORE)

check: core-test build

stop:
	-pkill -x ScreenshotXX

run: build stop
	open $(APP)

clean:
	rm -rf build $(CORE)/.build $(PROJECT)
```

Add `ScreenshotXX/Info.plist` to `.gitignore` (XcodeGen regenerates it from `project.yml`).

- [ ] **Step 6: App sources**

`ScreenshotXX/App/ScreenshotXXApp.swift`:

```swift
import SwiftUI
import ScreenshotXXCore

@main
struct ScreenshotXXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ScreenshotXX", systemImage: "camera.viewfinder") {
            MenuBarMenu()
                .environment(appDelegate.captureCoordinator)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appDelegate.settings)
        }
    }
}
```

`ScreenshotXX/App/AppDelegate.swift`:

```swift
import AppKit
import ScreenshotXXCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private(set) lazy var captureCoordinator = CaptureCoordinator(settings: settings)
    private var hotkeys: HotkeyService?
    private var onboarding: PermissionOnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hotkeys = HotkeyService(coordinator: captureCoordinator)
        hotkeys.register()
        self.hotkeys = hotkeys

        if !PermissionService.hasScreenRecordingAccess {
            showOnboarding()
        }
    }

    func showOnboarding() {
        let controller = onboarding ?? PermissionOnboardingWindowController()
        onboarding = controller
        controller.showWindow(nil)
        NSApp.activate()
    }
}
```

`ScreenshotXX/App/MenuBarMenu.swift`:

```swift
import SwiftUI
import ScreenshotXXCore

struct MenuBarMenu: View {
    @Environment(CaptureCoordinator.self) private var coordinator

    var body: some View {
        Button("Capture Area") { coordinator.capture(.area) }
        Button("Capture Window") { coordinator.capture(.window) }
        Button("Capture Full Screen") { coordinator.capture(.fullScreen) }
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Divider()
        Button("Quit ScreenshotXX") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
```

`ScreenshotXX/Capture/CaptureCoordinator.swift` (stub, replaced in Task 2):

```swift
import Foundation
import os
import ScreenshotXXCore

@Observable
final class CaptureCoordinator {
    private let settings: AppSettings
    @ObservationIgnored private let log = Logger(subsystem: "com.austinejose.screenshotxx", category: "capture")

    init(settings: AppSettings) {
        self.settings = settings
    }

    func capture(_ kind: CaptureKind) {
        log.notice("capture requested: \(kind.rawValue, privacy: .public)")
    }
}
```

`ScreenshotXX/Services/HotkeyService.swift`:

```swift
import KeyboardShortcuts
import ScreenshotXXCore

extension KeyboardShortcuts.Name {
    static let captureArea = Self("captureArea", default: .init(.a, modifiers: [.control, .shift]))
    static let captureWindow = Self("captureWindow", default: .init(.w, modifiers: [.control, .shift]))
    static let captureFullScreen = Self("captureFullScreen", default: .init(.f, modifiers: [.control, .shift]))
}

final class HotkeyService {
    private let coordinator: CaptureCoordinator

    init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
    }

    func register() {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [coordinator] in coordinator.capture(.area) }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [coordinator] in coordinator.capture(.window) }
        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [coordinator] in coordinator.capture(.fullScreen) }
    }
}
```

`ScreenshotXX/Services/PermissionService.swift`:

```swift
import AppKit
import CoreGraphics

enum PermissionService {
    static var hasScreenRecordingAccess: Bool { CGPreflightScreenCaptureAccess() }

    @discardableResult
    static func requestScreenRecordingAccess() -> Bool { CGRequestScreenCaptureAccess() }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
```

`ScreenshotXX/Onboarding/PermissionOnboardingView.swift`:

```swift
import SwiftUI

struct PermissionOnboardingView: View {
    @State private var granted = PermissionService.hasScreenRecordingAccess
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("ScreenshotXX needs Screen Recording access")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("macOS asks for this once. Without it, every capture comes back black.\nAfter you allow it, quit and reopen ScreenshotXX.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Open System Settings") { PermissionService.openScreenRecordingSettings() }
                Button("Allow Access") { PermissionService.requestScreenRecordingAccess() }
                    .buttonStyle(.borderedProminent)
            }
            Label(granted ? "Access granted" : "Not granted yet",
                  systemImage: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .secondary)
            Button("Done") { onDone() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 440)
        .onReceive(poll) { _ in granted = PermissionService.hasScreenRecordingAccess }
    }
}
```

`ScreenshotXX/Onboarding/PermissionOnboardingWindowController.swift`:

```swift
import AppKit
import SwiftUI

final class PermissionOnboardingWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to ScreenshotXX"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentViewController = NSHostingController(
            rootView: PermissionOnboardingView { [weak window] in window?.close() }
        )
        window.center()
    }
}
```

`ScreenshotXX/Settings/SettingsView.swift`:

```swift
import AppKit
import KeyboardShortcuts
import ScreenshotXXCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 460)
        .padding()
    }
}

private struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            LabeledContent("Save to") {
                HStack {
                    Text(settings.saveFolder.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…") { chooseFolder() }
                }
            }
            Picker("Format", selection: $settings.imageFormat) {
                ForEach(ImageFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
            }
            Toggle("Copy to clipboard after capture", isOn: $settings.copiesToClipboard)
            Toggle("Show mouse cursor", isOn: $settings.showsCursor)
            Toggle("Play shutter sound", isOn: $settings.playsSound)
            Stepper(value: $settings.cardAutoCloseSeconds, in: 0...120, step: 5) {
                Text(settings.cardAutoCloseSeconds == 0
                     ? "Keep card until closed"
                     : "Close card after \(settings.cardAutoCloseSeconds) s")
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.saveFolder
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolder = url
        }
    }
}

private struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture area", name: .captureArea)
            KeyboardShortcuts.Recorder("Capture window", name: .captureWindow)
            KeyboardShortcuts.Recorder("Capture full screen", name: .captureFullScreen)
        }
    }
}
```

- [ ] **Step 7: Build the app**

Run: `make build`
Expected: exit 0, no errors. `build/DerivedData/Build/Products/Debug/ScreenshotXX.app` exists.

- [ ] **Step 8: Launch and verify by hand**

Run: `make run`, then `sleep 3; pgrep -x ScreenshotXX`
Expected: a PID. The menu bar shows a viewfinder icon. The onboarding window appears if Screen Recording is not granted.

Trigger a capture via the menu bar (or hotkey ⌃⇧F) and read the log:
Run: `log show --last 2m --predicate 'subsystem == "com.austinejose.screenshotxx"' --style compact`
Expected: a line containing `capture requested: fullScreen`.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: project skeleton — menu bar app, settings, onboarding, hotkeys"
```

Task test command: `make check`
