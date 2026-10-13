# ClearShot v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu-bar screenshot app (area / window / full screen) with a bottom-of-screen Quick Access card and a full annotation editor.

**Architecture:** SwiftUI views inside an AppKit shell (NSPanel for the card, NSWindow overlays for selection). ScreenCaptureKit `SCScreenshotManager` for capture. Pure logic (settings, geometry, models, layout, undo) lives in a local Swift package `Packages/ClearShotCore` so it builds and tests with `swift test` in seconds; the app target depends on it.

**Tech Stack:** Swift 6 (toolchain 6.4), SwiftUI + AppKit, ScreenCaptureKit, Swift Testing, XcodeGen 2.46, KeyboardShortcuts 3.1.0.

**Spec:** `docs/superpowers/specs/2026-10-13-clearshot-design.md`

**Plan style note:** Tasks are written just-in-time, one phase of the spec at a time, so each brief reflects what the previous phase actually produced. Task N = Phase N of the spec.

## Global Constraints

- Minimum macOS: 26.0. SDK: macOS 27.0 (Xcode 27.0).
- Bundle id: `com.austinejose.clearshot`. App name: `ClearShot`. `LSUIElement = true` (menu bar only).
- Swift 6 language mode, strict concurrency complete. App target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; the Core package uses nonisolated default.
- No App Sandbox. Signing: ad-hoc (`CODE_SIGN_IDENTITY = -`) until `Local.xcconfig` sets a Personal Team.
- Default hotkeys: ⌃⇧A area, ⌃⇧W window, ⌃⇧F full screen.
- Default save folder `~/Pictures/ClearShot/`, default format PNG, copy to clipboard on.
- Core package must not import AppKit, SwiftUI or ScreenCaptureKit (Foundation, CoreGraphics, ImageIO and UniformTypeIdentifiers only).
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
- Create: `Packages/ClearShotCore/Package.swift`
- Create: `Packages/ClearShotCore/Sources/ClearShotCore/Settings/AppSettings.swift`
- Create: `Packages/ClearShotCore/Sources/ClearShotCore/Capture/CaptureKind.swift`
- Test: `Packages/ClearShotCore/Tests/ClearShotCoreTests/AppSettingsTests.swift`
- Create: `ClearShot/App/ClearShotApp.swift`, `ClearShot/App/AppDelegate.swift`, `ClearShot/App/MenuBarMenu.swift`
- Create: `ClearShot/Capture/CaptureCoordinator.swift` (Phase 1 stub: logs only)
- Create: `ClearShot/Services/HotkeyService.swift`, `ClearShot/Services/PermissionService.swift`
- Create: `ClearShot/Onboarding/PermissionOnboardingView.swift`, `ClearShot/Onboarding/PermissionOnboardingWindowController.swift`
- Create: `ClearShot/Settings/SettingsView.swift`

**Interfaces:**
- Produces (Core): `public enum ImageFormat: String, CaseIterable, Sendable, Codable { case png, jpeg; public var fileExtension: String }`
- Produces (Core): `@Observable public final class AppSettings { public init(defaults: UserDefaults = .standard); public static let defaultSaveFolder: URL; public var saveFolder: URL; public var imageFormat: ImageFormat; public var copiesToClipboard: Bool; public var showsCursor: Bool; public var playsSound: Bool; public var cardAutoCloseSeconds: Int /* 0 = never */ }`
- Produces (Core): `public enum CaptureKind: String, Sendable, CaseIterable { case area, window, fullScreen }`
- Produces (App): `@Observable final class CaptureCoordinator { init(settings: AppSettings); func capture(_ kind: CaptureKind) }` — Task 2 replaces the body.
- Produces (App): `enum PermissionService { static var hasScreenRecordingAccess: Bool; static func requestScreenRecordingAccess() -> Bool; static func openScreenRecordingSettings() }`
- Produces (App): `KeyboardShortcuts.Name.captureArea / .captureWindow / .captureFullScreen`
- Produces (build): `make gen | build | run | stop | core-test | check`. `make check` = `core-test` + `build`.

- [ ] **Step 1: Write the failing Core test**

`Packages/ClearShotCore/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClearShotCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ClearShotCore", targets: ["ClearShotCore"]),
    ],
    targets: [
        .target(name: "ClearShotCore"),
        .testTarget(name: "ClearShotCoreTests", dependencies: ["ClearShotCore"]),
    ]
)
```

`Packages/ClearShotCore/Tests/ClearShotCoreTests/AppSettingsTests.swift`:

```swift
import Foundation
import Testing
@testable import ClearShotCore

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
        #expect(settings.saveFolder.path().hasSuffix("/Pictures/ClearShot/"))
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

Run: `swift test --package-path Packages/ClearShotCore`
Expected: FAIL to compile — `cannot find 'AppSettings' in scope` (the Sources target needs at least one file; add an empty `CaptureKind.swift` first if SwiftPM complains about an empty target).

- [ ] **Step 3: Implement AppSettings and CaptureKind**

`Packages/ClearShotCore/Sources/ClearShotCore/Capture/CaptureKind.swift`:

```swift
public enum CaptureKind: String, Sendable, CaseIterable {
    case area, window, fullScreen
}
```

`Packages/ClearShotCore/Sources/ClearShotCore/Settings/AppSettings.swift`:

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
        .appending(path: "Pictures/ClearShot", directoryHint: .isDirectory)

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

Run: `swift test --package-path Packages/ClearShotCore`
Expected: `Test run with 3 tests passed`

- [ ] **Step 5: Project files (configuration — no test)**

`project.yml`:

```yaml
name: ClearShot
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
  ClearShotCore:
    path: Packages/ClearShotCore
targets:
  ClearShot:
    type: application
    platform: macOS
    sources:
      - path: ClearShot
        excludes: ["Info.plist"]
    dependencies:
      - package: KeyboardShortcuts
      - package: ClearShotCore
    info:
      path: ClearShot/Info.plist
      properties:
        CFBundleDisplayName: ClearShot
        LSUIElement: true
        LSApplicationCategoryType: public.app-category.productivity
        NSHumanReadableCopyright: "© 2026 Austine Jose"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.austinejose.clearshot
        PRODUCT_NAME: ClearShot
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
        SWIFT_APPROACHABLE_CONCURRENCY: YES
    configFiles:
      Debug: Local.xcconfig
      Release: Local.xcconfig
schemes:
  ClearShot:
    build:
      targets:
        ClearShot: all
    run:
      config: Debug
```

`Makefile`:

```make
PROJECT := ClearShot.xcodeproj
SCHEME  := ClearShot
DERIVED := build/DerivedData
APP     := $(DERIVED)/Build/Products/Debug/ClearShot.app
CORE    := Packages/ClearShotCore

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
	-pkill -x ClearShot

run: build stop
	open $(APP)

clean:
	rm -rf build $(CORE)/.build $(PROJECT)
```

Add `ClearShot/Info.plist` to `.gitignore` (XcodeGen regenerates it from `project.yml`).

- [ ] **Step 6: App sources**

`ClearShot/App/ClearShotApp.swift`:

```swift
import SwiftUI
import ClearShotCore

@main
struct ClearShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ClearShot", systemImage: "camera.viewfinder") {
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

`ClearShot/App/AppDelegate.swift`:

```swift
import AppKit
import ClearShotCore

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

`ClearShot/App/MenuBarMenu.swift`:

```swift
import SwiftUI
import ClearShotCore

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
        Button("Quit ClearShot") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
```

`ClearShot/Capture/CaptureCoordinator.swift` (stub, replaced in Task 2):

```swift
import Foundation
import os
import ClearShotCore

@Observable
final class CaptureCoordinator {
    private let settings: AppSettings
    @ObservationIgnored private let log = Logger(subsystem: "com.austinejose.clearshot", category: "capture")

    init(settings: AppSettings) {
        self.settings = settings
    }

    func capture(_ kind: CaptureKind) {
        log.notice("capture requested: \(kind.rawValue, privacy: .public)")
    }
}
```

`ClearShot/Services/HotkeyService.swift`:

```swift
import KeyboardShortcuts
import ClearShotCore

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

`ClearShot/Services/PermissionService.swift`:

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

`ClearShot/Onboarding/PermissionOnboardingView.swift`:

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
            Text("ClearShot needs Screen Recording access")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("macOS asks for this once. Without it, every capture comes back black.\nAfter you allow it, quit and reopen ClearShot.")
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

`ClearShot/Onboarding/PermissionOnboardingWindowController.swift`:

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
        window.title = "Welcome to ClearShot"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentViewController = NSHostingController(
            rootView: PermissionOnboardingView { [weak window] in window?.close() }
        )
        window.center()
    }
}
```

`ClearShot/Settings/SettingsView.swift`:

```swift
import AppKit
import KeyboardShortcuts
import ClearShotCore
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
Expected: exit 0, no errors. `build/DerivedData/Build/Products/Debug/ClearShot.app` exists.

- [ ] **Step 8: Launch and verify by hand**

Run: `make run`, then `sleep 3; pgrep -x ClearShot`
Expected: a PID. The menu bar shows a viewfinder icon. The onboarding window appears if Screen Recording is not granted.

Trigger a capture via the menu bar (or hotkey ⌃⇧F) and read the log:
Run: `log show --last 2m --predicate 'subsystem == "com.austinejose.clearshot"' --style compact`
Expected: a line containing `capture requested: fullScreen`.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: project skeleton — menu bar app, settings, onboarding, hotkeys"
```

Task test command: `make check`

---

### Task 2: Full-screen capture → PNG on disk, clipboard, shutter sound

**Files:**
- Create (Core): `Packages/ClearShotCore/Sources/ClearShotCore/Capture/Capture.swift`, `.../Capture/CaptureStore.swift`, `.../Files/FileNamer.swift`
- Test (Core): `Packages/ClearShotCore/Tests/ClearShotCoreTests/FileNamerTests.swift`, `.../CaptureStoreTests.swift`
- Create (App): `ClearShot/Capture/ScreenCapturer.swift`, `ClearShot/Services/FileSaver.swift`, `ClearShot/Services/ClipboardService.swift`, `ClearShot/Services/SoundPlayer.swift`, `ClearShot/Services/ErrorPresenter.swift`
- Modify (App): `ClearShot/Capture/CaptureCoordinator.swift` (replace the stub), `ClearShot/App/AppDelegate.swift` (own a `CaptureStore`, pass it and the onboarding callback)

**Interfaces:**
- Consumes: `AppSettings` (Task 1), `CaptureKind` (Task 1), `PermissionService` (Task 1).
- Produces (Core): `public struct Capture: Identifiable, Sendable { public let id: UUID; public let kind: CaptureKind; public let createdAt: Date; public let image: CGImage; public var fileURL: URL?; public init(kind: CaptureKind, image: CGImage, createdAt: Date = .now, fileURL: URL? = nil) }`
- Produces (Core): `@Observable public final class CaptureStore { public init(limit: Int = 20); public private(set) var captures: [Capture] /* newest first */; public func add(_:); public func remove(id: Capture.ID); public func capture(id: Capture.ID) -> Capture?; public func update(_:) }`
- Produces (Core): `public enum FileNamer { static func fileName(date: Date, format: ImageFormat, timeZone: TimeZone = .current) -> String /* "ClearShot 2026-10-13 at 09.41.12.png" */; static func uniqueFileName(_ name: String, exists: (String) -> Bool) -> String /* "name (2).png" */ }`
- Produces (App): `enum ScreenCapturer { static func display(under point: CGPoint) async throws -> SCDisplay; static func captureDisplay(_ display: SCDisplay, showsCursor: Bool) async throws -> CGImage }`
- Produces (App): `enum FileSaver { static func save(_ image: CGImage, format: ImageFormat, to folder: URL, date: Date) throws -> URL }` — creates the folder if missing, never overwrites (uses `FileNamer.uniqueFileName`).
- Produces (App): `enum ClipboardService { static func copy(_ image: CGImage) }` (PNG + TIFF on the general pasteboard)
- Produces (App): `enum SoundPlayer { static func playShutter() }`
- Produces (App): `enum ErrorPresenter { static func show(title: String, message: String) }` (NSAlert, brings the app forward)
- Produces (App): `CaptureCoordinator.init(settings: AppSettings, store: CaptureStore, onPermissionMissing: @escaping () -> Void)`; `.capture(.fullScreen)` runs the whole pipeline; `.area` / `.window` still log only (Tasks 3 and 4).

- [ ] **Step 1: Write the failing Core tests**

`FileNamerTests.swift`:

```swift
import Foundation
import Testing
@testable import ClearShotCore

@Suite struct FileNamerTests {
    private let dublin = TimeZone(identifier: "Europe/Dublin")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = dublin
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    @Test func nameUsesDateThenTimeWithDots() {
        let at = date(2026, 10, 13, 9, 41, 12)
        #expect(FileNamer.fileName(date: at, format: .png, timeZone: dublin) == "ClearShot 2026-10-13 at 09.41.12.png")
        #expect(FileNamer.fileName(date: at, format: .jpeg, timeZone: dublin) == "ClearShot 2026-10-13 at 09.41.12.jpg")
    }

    @Test func uniqueNameAddsCounterOnlyWhenTaken() {
        let taken: Set<String> = ["shot.png", "shot (2).png"]
        #expect(FileNamer.uniqueFileName("shot.png", exists: { taken.contains($0) }) == "shot (3).png")
        #expect(FileNamer.uniqueFileName("other.png", exists: { taken.contains($0) }) == "other.png")
    }
}
```

`CaptureStoreTests.swift`:

```swift
import CoreGraphics
import Foundation
import Testing
@testable import ClearShotCore

@Suite struct CaptureStoreTests {
    private func pixel() -> CGImage {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    @Test func addKeepsNewestFirstAndRespectsLimit() {
        let store = CaptureStore(limit: 2)
        let first = Capture(kind: .fullScreen, image: pixel())
        let second = Capture(kind: .fullScreen, image: pixel())
        let third = Capture(kind: .fullScreen, image: pixel())
        store.add(first); store.add(second); store.add(third)
        #expect(store.captures.map(\.id) == [third.id, second.id])
    }

    @Test func removeDropsOnlyThatCapture() {
        let store = CaptureStore()
        let a = Capture(kind: .area, image: pixel())
        let b = Capture(kind: .area, image: pixel())
        store.add(a); store.add(b)
        store.remove(id: a.id)
        #expect(store.captures.map(\.id) == [b.id])
    }

    @Test func updateReplacesTheStoredCopy() {
        let store = CaptureStore()
        var a = Capture(kind: .window, image: pixel())
        store.add(a)
        a.fileURL = URL(filePath: "/tmp/a.png")
        store.update(a)
        #expect(store.capture(id: a.id)?.fileURL?.path() == "/tmp/a.png")
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/ClearShotCore`
Expected: compile errors `cannot find 'FileNamer' in scope`, `cannot find 'CaptureStore' in scope`, `cannot find 'Capture' in scope`.

- [ ] **Step 3: Implement Capture, CaptureStore, FileNamer**

`Capture.swift`:

```swift
import CoreGraphics
import Foundation

public struct Capture: Identifiable, Sendable {
    public let id: UUID
    public let kind: CaptureKind
    public let createdAt: Date
    public let image: CGImage
    public var fileURL: URL?

    public init(kind: CaptureKind, image: CGImage, createdAt: Date = .now, fileURL: URL? = nil) {
        self.id = UUID()
        self.kind = kind
        self.createdAt = createdAt
        self.image = image
        self.fileURL = fileURL
    }
}
```

`CaptureStore.swift`:

```swift
import Foundation
import Observation

/// Recent captures, newest first. In memory only; files on disk are the real history.
@Observable
public final class CaptureStore {
    public private(set) var captures: [Capture] = []
    public let limit: Int

    public init(limit: Int = 20) {
        self.limit = limit
    }

    public func add(_ capture: Capture) {
        captures.insert(capture, at: 0)
        if captures.count > limit { captures.removeLast(captures.count - limit) }
    }

    public func remove(id: Capture.ID) {
        captures.removeAll { $0.id == id }
    }

    public func capture(id: Capture.ID) -> Capture? {
        captures.first { $0.id == id }
    }

    public func update(_ capture: Capture) {
        guard let index = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[index] = capture
    }
}
```

`FileNamer.swift`:

```swift
import Foundation

public enum FileNamer {
    /// "ClearShot 2026-10-13 at 09.41.12.png" — same shape as macOS's own screenshots.
    public static func fileName(date: Date, format: ImageFormat, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "ClearShot \(formatter.string(from: date)).\(format.fileExtension)"
    }

    /// Adds " (2)", " (3)", … before the extension until `exists` says the name is free.
    public static func uniqueFileName(_ name: String, exists: (String) -> Bool) -> String {
        guard exists(name) else { return name }
        let url = URL(filePath: name)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 2
        while true {
            let candidate = "\(stem) (\(counter)).\(ext)"
            if !exists(candidate) { return candidate }
            counter += 1
        }
    }
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `swift test --package-path Packages/ClearShotCore`
Expected: `Test run with 8 tests in 3 suites passed`.

- [ ] **Step 5: App services and capture pipeline**

`ScreenCapturer.swift`:

```swift
import AppKit
import ScreenCaptureKit

enum ScreenCapturer {
    enum Failure: LocalizedError {
        case noDisplay
        case noImage

        var errorDescription: String? {
            switch self {
            case .noDisplay: "No display found to capture."
            case .noImage: "The system returned no image."
            }
        }
    }

    /// The SCDisplay for the screen that contains `point` (AppKit screen coordinates). Falls back to the main display.
    static func display(under point: CGPoint) async throws -> SCDisplay {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let wantedID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        if let match = content.displays.first(where: { $0.displayID == wantedID }) { return match }
        guard let first = content.displays.first else { throw Failure.noDisplay }
        return first
    }

    static func captureDisplay(_ display: SCDisplay, showsCursor: Bool) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCScreenshotConfiguration()
        configuration.showsCursor = showsCursor
        configuration.dynamicRange = .sdr
        let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        guard let image = output.sdrImage else { throw Failure.noImage }
        return image
    }
}
```

`FileSaver.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import ClearShotCore
import UniformTypeIdentifiers

enum FileSaver {
    enum Failure: LocalizedError {
        case encodingFailed(URL)
        var errorDescription: String? {
            switch self {
            case .encodingFailed(let url): "Could not write the image to \(url.path())."
            }
        }
    }

    static func save(_ image: CGImage, format: ImageFormat, to folder: URL, date: Date = .now) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = FileNamer.uniqueFileName(FileNamer.fileName(date: date, format: format)) { candidate in
            fileManager.fileExists(atPath: folder.appending(path: candidate).path())
        }
        let url = folder.appending(path: name)
        let type: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw Failure.encodingFailed(url)
        }
        let options: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.9] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed(url) }
        return url
    }
}
```

`ClipboardService.swift`:

```swift
import AppKit

enum ClipboardService {
    static func copy(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        if let tiff = nsImage.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
    }
}
```

`SoundPlayer.swift` (uses the system screenshot sound when present, else a short system click):

```swift
import AppKit

enum SoundPlayer {
    private static let shutterCandidates = [
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif",
    ]

    static func playShutter() {
        let sound = shutterCandidates.lazy.compactMap { NSSound(contentsOfFile: $0, byReference: true) }.first
            ?? NSSound(named: "Pop")
        sound?.play()
    }
}
```

`ErrorPresenter.swift`:

```swift
import AppKit

enum ErrorPresenter {
    static func show(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate()
        alert.runModal()
    }
}
```

`CaptureCoordinator.swift` (full replacement):

```swift
import AppKit
import os
import ClearShotCore

@Observable
final class CaptureCoordinator {
    private let settings: AppSettings
    private let store: CaptureStore
    private let onPermissionMissing: () -> Void
    @ObservationIgnored private let log = Logger(subsystem: "com.austinejose.clearshot", category: "capture")

    init(settings: AppSettings, store: CaptureStore, onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.store = store
        self.onPermissionMissing = onPermissionMissing
    }

    func capture(_ kind: CaptureKind) {
        guard PermissionService.hasScreenRecordingAccess else {
            onPermissionMissing()
            return
        }
        switch kind {
        case .fullScreen:
            Task { await captureFullScreen() }
        case .area, .window:
            log.notice("capture requested: \(kind.rawValue, privacy: .public) (not implemented yet)")
        }
    }

    private func captureFullScreen() async {
        do {
            let display = try await ScreenCapturer.display(under: NSEvent.mouseLocation)
            let image = try await ScreenCapturer.captureDisplay(display, showsCursor: settings.showsCursor)
            finish(Capture(kind: .fullScreen, image: image))
        } catch {
            ErrorPresenter.show(title: "Capture failed", message: error.localizedDescription)
        }
    }

    /// Shared tail of every capture: clipboard first (never lost), then disk, then sound and store.
    private func finish(_ capture: Capture) {
        var capture = capture
        if settings.copiesToClipboard { ClipboardService.copy(capture.image) }
        do {
            capture.fileURL = try FileSaver.save(capture.image, format: settings.imageFormat, to: settings.saveFolder, date: capture.createdAt)
        } catch {
            ErrorPresenter.show(title: "Could not save the screenshot",
                                message: "\(error.localizedDescription)\n\nIt is still on your clipboard.")
        }
        if settings.playsSound { SoundPlayer.playShutter() }
        store.add(capture)
    }
}
```

`AppDelegate.swift` changes: add `let captureStore = CaptureStore()` and build the coordinator as
`CaptureCoordinator(settings: settings, store: captureStore) { [weak self] in self?.showOnboarding() }`.

- [ ] **Step 6: Build**

Run: `make build`
Expected: exit 0, no warnings.

- [ ] **Step 7: Verify by hand (Austin launches; I check the file)**

Austin: `! open ~/Development/Personal/clearshot/build/DerivedData/Build/Products/Debug/ClearShot.app`, then press ⌃⇧F. First time macOS asks for Screen Recording; allow it, quit and reopen, press ⌃⇧F again.
Run: `ls -la ~/Pictures/ClearShot/ && sips -g pixelWidth -g pixelHeight ~/Pictures/ClearShot/*.png`
Expected: one PNG named `ClearShot <date> at <time>.png`; pixel size equals the display's pixel size (Retina: 2× the point size).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: full-screen capture to PNG, clipboard and shutter sound"
```

Task test command: `make check`

---

### Task 3: Area capture — frozen screen, drag a rectangle, size label, Esc cancels

**Files:**
- Create (Core): `Packages/ClearShotCore/Sources/ClearShotCore/Capture/SelectionGeometry.swift`
- Test (Core): `Packages/ClearShotCore/Tests/ClearShotCoreTests/SelectionGeometryTests.swift`
- Create (App): `ClearShot/Capture/AreaCaptureSession.swift`, `ClearShot/Capture/SelectionOverlayWindow.swift`, `ClearShot/Capture/SelectionOverlayView.swift`
- Modify (App): `ClearShot/Capture/ScreenCapturer.swift` (add `screenDisplays()`), `ClearShot/Capture/CaptureCoordinator.swift` (`.area` runs the session)

**Interfaces:**
- Consumes: `ScreenCapturer.captureDisplay(_:showsCursor:)`, `CaptureCoordinator.finish(_:)` (Task 2), `Capture` (Task 2).
- Produces (Core): `public enum SelectionGeometry { static let minimumSize: CGFloat = 3; static func normalizedRect(from: CGPoint, to: CGPoint) -> CGRect; static func isUsable(_ rect: CGRect) -> Bool; static func pixelRect(viewRect: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect /* whole pixels, clamped to the image */ }`
- Produces (App): `ScreenCapturer.screenDisplays() async throws -> [(screen: NSScreen, display: SCDisplay)]`
- Produces (App): `@MainActor final class AreaCaptureSession { enum Outcome { case selected(CGImage); case cancelled }; static func run(showsCursor: Bool) async throws -> Outcome }` — snapshots every screen, shows one overlay per screen, resolves on the first drag-end or Esc, then closes all overlays.
- Produces (App): `final class SelectionOverlayWindow: NSWindow` (borderless, `.screenSaver` level, key window, Esc → `onCancel`).
- Produces (App): `struct SelectionOverlayView: View` with `init(frozen: CGImage, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void)`; the rect it reports is in view points (top-left origin).

Design notes:
- The frozen image has the same aspect as the overlay view, so a view rect maps to image pixels by one scale factor. No AppKit coordinate flip is needed anywhere in Task 3.
- Dimming uses one even-odd path (screen rect + selection rect), so the selection shows the undimmed frozen image.
- A drag smaller than 3 pt is a click: cancel.

- [ ] **Step 1: Write the failing Core tests**

```swift
import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct SelectionGeometryTests {
    @Test func normalizedRectWorksInAnyDragDirection() {
        let rect = SelectionGeometry.normalizedRect(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 10, y: 20))
        #expect(rect == CGRect(x: 10, y: 20, width: 90, height: 80))
    }

    @Test func tinyDragIsNotUsable() {
        #expect(SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 2, height: 10)) == false)
        #expect(SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 3, height: 3)) == true)
    }

    @Test func pixelRectScalesByImageOverView() {
        let rect = SelectionGeometry.pixelRect(viewRect: CGRect(x: 10, y: 20, width: 100, height: 50),
                                               viewSize: CGSize(width: 1800, height: 1169),
                                               imageSize: CGSize(width: 3600, height: 2338))
        #expect(rect == CGRect(x: 20, y: 40, width: 200, height: 100))
    }

    @Test func pixelRectIsClampedToTheImage() {
        let rect = SelectionGeometry.pixelRect(viewRect: CGRect(x: 1750, y: 1100, width: 100, height: 100),
                                               viewSize: CGSize(width: 1800, height: 1169),
                                               imageSize: CGSize(width: 3600, height: 2338))
        #expect(rect == CGRect(x: 3500, y: 2200, width: 100, height: 138))
    }

    @Test func pixelRectUsesWholePixelsThatCoverTheSelection() {
        let rect = SelectionGeometry.pixelRect(viewRect: CGRect(x: 10.4, y: 20.6, width: 100, height: 50),
                                               viewSize: CGSize(width: 1800, height: 1169),
                                               imageSize: CGSize(width: 3600, height: 2338))
        #expect(rect == CGRect(x: 20, y: 41, width: 201, height: 101))
    }
}
```

- [ ] **Step 2: Run to verify it fails** — `swift test --package-path Packages/ClearShotCore` → `cannot find 'SelectionGeometry' in scope`.
- [ ] **Step 3: Implement SelectionGeometry** (normalize with min/abs; `isUsable` compares to `minimumSize`; `pixelRect` scales by `imageSize.width / viewSize.width`, applies `.integral`, then `.intersection` with the image bounds).
- [ ] **Step 4: Run to verify it passes** → `16 tests in 6 suites passed`.
- [ ] **Step 5: App: ScreenCapturer.screenDisplays, SelectionOverlayWindow, SelectionOverlayView, AreaCaptureSession; CaptureCoordinator.area → run session → crop frozen image with `SelectionGeometry.pixelRect` → `finish(Capture(kind: .area, image:))`; cancelled → log only.**
- [ ] **Step 6: Build** — `make build` → no errors, no warnings.
- [ ] **Step 7: Verify by hand** — Austin: relaunch, ⌃⇧A, screen dims, drag a box, size label shows W × H, release → shutter. Esc on a second try → nothing saved. I check: new PNG whose pixel size is 2× the label, and `ClearShot.log` has `area selected` then `saved`.
- [ ] **Step 8: Commit** — `git commit -m "feat: area capture with frozen-screen overlay"`

Task test command: `make check`

---

### Task 4: Window capture — hover highlights a window, click captures it with its shadow, Space toggles area/window

**Files:**
- Create (Core): `.../Capture/WindowInfo.swift`, `.../Capture/WindowPicker.swift`, `.../Capture/ScreenCoordinates.swift`
- Test (Core): `WindowPickerTests.swift`, `ScreenCoordinatesTests.swift`
- Create (App): `ClearShot/Capture/OverlayState.swift`, `ClearShot/Capture/CaptureOverlayView.swift`, `ClearShot/Capture/WindowPickOverlayView.swift`
- Modify (App): `AreaCaptureSession.swift` → renamed `OverlayCaptureSession.swift` (mode + window outcome), `SelectionOverlayWindow.swift` (Space → `onToggleMode`), `ScreenCapturer.swift` (`windows()`, `captureWindow(_:showsCursor:includeShadow:)`), `CaptureCoordinator.swift`

**Interfaces:**
- Consumes: `SelectionOverlayView`, `SelectionOverlayWindow`, `SelectionGeometry` (Task 3); `finish(_:)` (Task 2).
- Produces (Core): `public struct WindowInfo: Identifiable, Sendable, Equatable { id: UInt32; frame: CGRect /* Quartz: top-left origin, global */; title: String?; ownerBundleID: String?; layer: Int; isOnScreen: Bool }`
- Produces (Core): `public enum WindowPicker { static let minimumSize: CGFloat = 50; static func candidates(_: [WindowInfo], excludingBundleID: String) -> [WindowInfo] /* keeps input order */; static func window(at: CGPoint, in: [WindowInfo]) -> WindowInfo? /* first match = front-most */ }`
- Produces (Core): `public enum ScreenCoordinates { static func quartzPoint(fromAppKit: CGPoint, primaryHeight: CGFloat) -> CGPoint; static func quartzRect(fromAppKit: CGRect, primaryHeight: CGFloat) -> CGRect; static func viewRect(fromQuartz: CGRect, screenQuartzFrame: CGRect) -> CGRect }`
- Produces (App): `OverlayCaptureSession.run(mode: Mode, showsCursor: Bool) async throws -> Outcome` with `enum Mode { area, window }`, `enum Outcome { area(CGImage), window(SCWindow), cancelled }`.
- Produces (App): `ScreenCapturer.windows() async throws -> [SCWindow]` (on-screen only, SCK order kept), `ScreenCapturer.captureWindow(_: SCWindow, showsCursor: Bool, includeShadow: Bool) async throws -> CGImage` (desktop-independent window filter, `ignoreShadows = !includeShadow`).
- Window shadow is always included in v1 (CleanShot default). A setting can come later.

- [ ] **Step 1: Failing Core tests** — `WindowPickerTests`: drops own bundle, non-zero layer, off-screen and < 50 pt windows, keeps order; `window(at:)` returns the first (front-most) match or nil. `ScreenCoordinatesTests`: AppKit (100,100) with primary height 1169 → Quartz (100,1069); AppKit rect (0,0,1800,25) → Quartz (0,1144,1800,25); Quartz window (2000,300,400,200) on a screen with Quartz frame origin (1800,0) → view rect (200,300,400,200).
- [ ] **Step 2: Run → `cannot find 'WindowPicker' / 'ScreenCoordinates'`.**
- [ ] **Step 3: Implement the three Core types.**
- [ ] **Step 4: Run → 23 tests pass.**
- [ ] **Step 5: App.** `OverlayState` (@Observable: `mode`, `windows: [WindowInfo]`). `CaptureOverlayView` shows `SelectionOverlayView` in area mode and `WindowPickOverlayView` in window mode. The window view converts hover points to Quartz (`screenQuartzFrame.origin + point`), finds the window with `WindowPicker.window(at:)`, draws a highlight (white 15 % fill, 2 pt accent stroke, title pill) and reports the pick on click. Panel: Space (keyCode 49) toggles the mode. Session: builds `WindowInfo` from `SCWindow`, resolves `.window(scWindow)`, coordinator captures it live and calls `finish(Capture(kind: .window, …))`. Log the first five window titles in SCK order to confirm front-to-back.
- [ ] **Step 6: Build.**
- [ ] **Step 7: Verify by hand** — Austin: ⌃⇧W, move over windows (highlight follows), click → shutter; the PNG has rounded corners and a shadow. Space inside ⌃⇧A switches to window mode. I check the log and the file.
- [ ] **Step 8: Commit** — `feat: window capture with hover highlight`

Task test command: `make check`

---

### Task 5: Quick Access card — floating card at the bottom-left after every capture

**Files:**
- Create (Core): `.../Overlay/QuickAccessLayout.swift`; Test: `QuickAccessLayoutTests.swift`
- Create (App): `ClearShot/Overlay/QuickAccessPanel.swift`, `QuickAccessController.swift`, `QuickAccessView.swift`
- Modify (App): `SelectionOverlayWindow.swift` (rename `SelectionHostingView` → `FirstMouseHostingView`, reused by the card), `OverlayCaptureSession.swift` (rename use), `CaptureCoordinator.swift` (`finish` shows the card), `AppDelegate.swift` (owns the controller)

**Interfaces:**
- Consumes: `Capture`, `CaptureStore`, `AppSettings.cardAutoCloseSeconds`, `ClipboardService` (Task 2).
- Produces (Core): `public enum QuickAccessLayout { static let cardSize = CGSize(width: 232, height: 212); static let margin: CGFloat = 16; static let gap: CGFloat = 8; static func maxVisible(in visibleFrame: CGRect) -> Int; static func frames(count: Int, in visibleFrame: CGRect) -> [CGRect] /* AppKit coords, index 0 = newest = left-most, y = visibleFrame.minY + margin */ }`
- Produces (App): `@MainActor final class QuickAccessController { init(settings: AppSettings, store: CaptureStore); func show(_ capture: Capture, on screen: NSScreen?); func close(id: Capture.ID); var onEdit: ((Capture) -> Void)? }` — cards newest-left, animated in/out, auto-close per setting (paused while hovered), re-laid out on screen changes; a card whose screen is gone moves to the main screen.
- Produces (App): `QuickAccessPanel: NSPanel` (borderless, non-activating, `.floating`, all Spaces, transparent, shadow on).
- Produces (App): `QuickAccessView` — thumbnail (drag out = file URL), `W × H` caption, toolbar: Edit, Copy, Reveal in Finder, Close. Liquid Glass container (`.glassEffect`), fallback `.ultraThinMaterial`.
- Edit is a stub until Task 6: it logs and opens the file with the default app.

- [ ] **Step 1: Failing Core test** — three cards on a visible frame (0, 0, 1800, 1100) → x = 16, 256, 496; y = 16; `maxVisible` on a 500-wide frame = 2; `frames(count: 5, …)` on that frame returns 2.
- [ ] **Step 2: Run → `cannot find 'QuickAccessLayout'`.**
- [ ] **Step 3: Implement.** — [ ] **Step 4: Run → 24 tests pass.**
- [ ] **Step 5: App** as in Interfaces. `finish` passes the screen under the mouse.
- [ ] **Step 6: Build.**
- [ ] **Step 7: Verify by hand** — Austin: capture twice; two cards bottom-left, newest left; Copy, Reveal, drag the thumbnail into a Finder window, Close. Set auto-close to 10 s in Settings and capture again: card leaves by itself.
- [ ] **Step 8: Commit** — `feat: quick access card after capture`

Task test command: `make check`

---

### Task 6: Editor core — window, canvas, select/move/resize/delete, undo/redo, line/arrow/pen/rect/ellipse, copy/save

**Files:**
- Create (Core): `.../Editor/RGBAColor.swift`, `Annotation.swift`, `AnnotationGeometry.swift`, `ArrowGeometry.swift`, `PathSmoother.swift`, `UndoStack.swift`, `DocumentState.swift`, `EditorDocument.swift`; `FileSaver.overwrite` added.
- Test (Core): `UndoStackTests`, `EditorDocumentTests`, `AnnotationGeometryTests`, `ArrowGeometryTests`, `PathSmootherTests`, `FileSaverTests` (+overwrite)
- Create (App): `ClearShot/Editor/EditorWindowController.swift`, `EditorWindow.swift` (key equivalents), `EditorSessionStore.swift`, `EditorView.swift`, `EditorToolbar.swift`, `EditorCanvasView.swift`, `CompositionView.swift`, `AnnotationView.swift`, `SelectionHandles.swift`, `Tools/EditorTool.swift`, `Exporter.swift`, `Color+RGBA.swift`
- Modify (App): `AppDelegate.swift` (Edit opens the editor), `QuickAccessController` unchanged.

**Interfaces (Core):**
- `RGBAColor { red, green, blue, alpha: Double; presets .red .orange .yellow .green .blue .purple .black .white }`
- `Annotation { id; kind: Kind; style: Style; init(kind:style:); bounds; hitTest(_:tolerance:) -> Bool; mutating move(by: CGVector) }`, `Kind: .line(start:end:arrowStart:arrowEnd:) .freehand(points:) .rect(CGRect) .ellipse(CGRect)`, `Style { strokeColor = .red; strokeWidth = 6; fillColor: RGBAColor? = nil }`. All coordinates are image pixels.
- `AnnotationGeometry.distance(from:toSegment:_:)`, `ArrowGeometry.head(from:to:length:width:) -> (left, right)`, `PathSmoother.segments(through:) -> (start, [Segment{control1, control2, end}])?` (Catmull-Rom → cubic Bézier).
- `UndoStack<State: Equatable> { init(initial:limit: = 100); current; canUndo; canRedo; push(_:) (no-op if equal); undo() -> State?; redo() -> State? }`
- `DocumentState: Equatable, Codable { annotations: [Annotation] }`
- `@Observable EditorDocument { init(baseImage:); baseImage; state; selection: Set<Annotation.ID>; annotations; add(_:) (commits); update(_:) (live, no undo entry); commit(); remove(ids:); undo(); redo(); canUndo; canRedo; hitTest(_:tolerance:) -> Annotation.ID? (top-most); annotation(id:); moveSelection(by:) (live) }`
- `FileSaver.overwrite(_ image: CGImage, format: ImageFormat, at url: URL) throws` — replaces the file in place.

**Interfaces (App):**
- `EditorSessionStore.shared.open(capture: Capture)` — one window per capture id; reopening brings the same document back.
- `EditorWindow: NSWindow` intercepts ⌘Z, ⇧⌘Z, Delete/Backspace, ⌘C, ⌘S, ⌘A, Esc via `performKeyEquivalent`/`keyDown` and forwards to `EditorActions` closures.
- `CompositionView(document:)` draws at 1 pt = 1 image pixel; the canvas shows it with `scaleEffect(zoom)`; `Exporter.render(document:) -> CGImage` uses `ImageRenderer` at scale 1 so the export has the source's pixel size.
- Tools: Select, Line, Arrow, Pen, Rect, Ellipse. Select: click picks top-most, drag moves, corner handles resize rect/ellipse, endpoint handles move line ends, Delete removes. Toolbar also has colour presets, stroke width, undo/redo, Copy, Save (overwrites the capture file; Save As… when there is no file).

- [ ] **Step 1: failing Core tests** (see test files) — **Step 2: run → missing types** — **Step 3: implement Core** — **Step 4: run → 41 tests pass**
- [ ] **Step 5: App editor** — **Step 6: build** — **Step 7: Austin: Edit on a card → editor opens; draw line, arrow, pen, rect, ellipse; move; resize; delete; undo/redo; Copy and Save; the saved PNG has the drawings at the source pixel size (I check with sips).** — **Step 8: commit `feat: editor core`**

Task test command: `make check`

---

### Task 7: Text (plain and boxed, bold, size, scale by handles) and a curved line

Ruling: caption and meme bar move to Task 8 — they change the canvas size, which the frame layout in Task 8 owns.

**Files:**
- Modify (Core): `Annotation.swift` (+ `.curve`, `.text`), create `TextContent.swift`, `CurveGeometry.swift`
- Test (Core): `CurveGeometryTests.swift`, `TextContentTests.swift`, additions to `AnnotationGeometryTests.swift`
- Modify (App): `EditorTool.swift` (+ curve, text), `AnnotationView.swift`, `SelectionHandles.swift`, `EditorCanvasView.swift` (text tool, inline editing), create `TextEditingOverlay.swift`, `EditorToolbar.swift` (arrowhead, font size, bold, boxed), `EditorState.swift`, `EditorWindow.swift` (Esc while editing goes to the field)

**Interfaces (Core):**
- `Kind.curve(start: CGPoint, control: CGPoint, end: CGPoint, arrowEnd: Bool)` — quadratic Bézier; control starts at the midpoint.
- `Kind.text(TextContent)`; `TextContent { text; origin (top-left); fontSize = 48; bold = true; boxed = false; measuredSize = .zero /* whole box, set by the view */; estimatedSize; frame; scaled(toWidth:) }`. Boxed text draws white text on a box of the stroke colour; plain text uses the stroke colour.
- `CurveGeometry.point(start:control:end:t:)`, `CurveGeometry.samples(start:control:end:count:)`.

**Interfaces (App):**
- Tools `curve` and `text`. Curve: drag start→end, then a middle handle bends it. Text: click places "Text" and starts editing; clicking an already-selected text edits it; Esc or clicking elsewhere ends editing; empty text is removed. Corner handles on text scale the font. Toolbar shows Arrowhead for line/curve, and Size / Bold / Boxed for text.

- [ ] **Step 1: failing Core tests** — **Step 2: run** — **Step 3: implement** — **Step 4: run → 50 tests pass** — **Step 5: App** — **Step 6: build** — **Step 7: Austin: curve with bend, text, boxed text, bold, size, scale by corner, edit again, save → PNG shows them** — **Step 8: commit `feat: text and curved line tools`**

Task test command: `make check`

---

### Task 8: Frame — padding, inset, corner radius, shadow, backgrounds, caption, meme bar

**Files:**
- Create (Core): `.../Editor/FrameStyle.swift` (FrameStyle, Background, GradientPreset), `.../Editor/CanvasLayout.swift`; modify `DocumentState.swift` (+frame), `EditorDocument.swift` (+frame, setFrame)
- Test (Core): `CanvasLayoutTests.swift`, `EditorDocumentTests` (+frame undo)
- Create (App): `ClearShot/Editor/FramePanelView.swift`, `BackgroundView.swift`, `CanvasTransform.swift`; modify `CompositionView.swift`, `EditorCanvasView.swift`, `SelectionHandles.swift`, `TextEditingOverlay.swift`, `EditorToolbar.swift` (Frame panel toggle), `EditorView.swift`, `EditorState.swift`, `Exporter.swift`

**Interfaces (Core):**
- `FrameStyle { padding = 0; inset = 0; cornerRadius = 0; shadow = false; background: Background = .none; caption = ""; memeTop = ""; memeBottom = "" }`
- `Background: .none | .solid(RGBAColor) | .gradient(GradientPreset) | .image(URL)`; `GradientPreset { id, name, start, end; static let all /* 8 */ }`
- `CanvasLayout(imageSize:frame:)`: `canvasSize`, `imageRect` (where the image is drawn, after padding, meme top bar and inset), `imageScale` (= drawn width / image width), `captionRect?`, `memeTopRect?`, `memeBottomRect?`, `captionFontSize`, `memeFontSize`, `imageToCanvas(_:)`, `canvasToImage(_:)`. Padding grows the canvas; inset shrinks the image inside the same canvas.
- `DocumentState.frame: FrameStyle`; `EditorDocument.frame`, `setFrame(_:)` (live; `commit()` records).

**Interfaces (App):** `FramePanelView` (right side, toggled from the toolbar): Background (None / colour presets / 8 gradients / Image…), Padding, Inset, Corner radius, Shadow, Caption, Meme top/bottom. `CompositionView` draws background → meme bars → image with annotations (clipped to rounded corners, shadow) → caption, at the canvas size. The canvas and overlays map image pixels through `CanvasTransform` (image scale × zoom + image origin).

- [ ] **Step 1: failing Core tests** — **Step 2: run** — **Step 3: implement** — **Step 4: run → 58 tests pass** — **Step 5: App** — **Step 6: build** — **Step 7: Austin: padding + gradient + rounded corners + shadow, inset, caption, meme bar; draw on the padded image (annotations stay on the image); Save → PNG size = 1280×880 for 1200×800 + 40 padding (I check with sips)** — **Step 8: commit `feat: frame — padding, inset, backgrounds, caption, meme bar`**

Task test command: `make check`

---

### Task 9: Fun and privacy — blur / pixelate, step numbers, speech bubbles (emoji removed at Austin's request)

**Files:**
- Modify (Core): `Annotation.swift` (+ `.blur`, `.step`, `.emoji`, `.speechBubble`), `EditorDocument.swift` (+ `nextStepNumber`); Test: `FunAnnotationTests.swift`
- Modify (App): `EditorTool.swift`, `AnnotationView.swift`, `SelectionHandles.swift`, `EditorCanvasView.swift`, `EditorToolbar.swift`, `EditorState.swift`, `TextEditingOverlay.swift`; create `BlurRegionView.swift`, `SpeechBubbleShape.swift`

**Interfaces (Core):**
- `BlurMode: pixelate | blur`
- `Kind.blur(rect:mode:)` — hides a region of the base image; `Kind.step(number:center:radius:)` — numbered circle; `Kind.emoji(character:center:size:rotation:)`; `Kind.speechBubble(rect:tail:text:fontSize:)` — white bubble, coloured border and text, tail point dragged by a handle.
- `EditorDocument.nextStepNumber` — 1 + the highest step so far.

**Interfaces (App):** tools Blur (mode option Pixelate/Blur), Step (click to place, numbers continue), Emoji (click to place the current emoji; quick row + a field to type any emoji), Bubble (drag a box, type the text, drag the tail). Blur renders the cropped base image through CIPixellate / CIGaussianBlur, cached per rect.

- [ ] **Step 1: failing Core tests** — **Step 2: run** — **Step 3: implement** — **Step 4: run → 62 tests pass** — **Step 5: App (two commits: blur + steps, then emoji + bubbles)** — **Step 6: build** — **Step 7: Austin: pixelate a region, blur one, three steps, two emojis, a bubble with text and a dragged tail; Save; PNG shows all** — **Step 8: commit**

Task test command: `make check`

---

### Task 10: Polish — app icon, crop tool, launch at login, log rotation, off-screen window filter, README

**Files:**
- Modify (Core): `DocumentState.swift` (base image becomes part of the state; Codable dropped — never persisted), `EditorDocument.swift` (+ `applyCrop`), `WindowPicker.swift` (+ `screens:`), `DiagnosticLog.swift` (+ `maxBytes` rotation)
- Test (Core): `EditorDocumentTests` (+crop), `WindowPickerTests` (+screens), `DiagnosticLogTests` (+rotation)
- Create (App): `ClearShot/Resources/AppIcon.icns` (made by `scripts/make-icon.swift`), `README.md`
- Modify (App): `EditorTool` (+crop), `EditorCanvasView` (crop drag + Apply/Cancel), `EditorToolbar`, `SettingsView` (launch at login, show log), `OverlayCaptureSession` (screen filter), `project.yml` (`CFBundleIconFile`)

**Interfaces (Core):**
- `DocumentState { baseImage: CGImage; annotations; frame }` (Equatable by reference for the image); `EditorDocument.applyCrop(_ rect: CGRect)` — crops the base image to whole pixels inside the image, shifts annotations by −origin, commits (undoable).
- `WindowPicker.candidates(_:excludingBundleID:screens: [CGRect] = [])` — with screens given, drops windows that touch none of them.
- `DiagnosticLog.write(_:to:maxBytes: = 2 MB)` — when the file is bigger than `maxBytes`, it starts over.

- [ ] **Step 1: failing Core tests** — **Step 2: run** — **Step 3: implement** — **Step 4: run → 61 tests pass** — **Step 5: App** — **Step 6: build** — **Step 7: Austin: app icon in Finder/Dock switcher; crop in the editor then undo; Launch at login toggle in Settings** — **Step 8: commit `feat: polish — icon, crop, launch at login`**

Task test command: `make check`
