# Capture Bar and Editor Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One on-screen capture bar opened from the menu (and ⇧⌘5), sticky editor tools, and new editor defaults (width 10, text 24).

**Architecture:** Pure decisions (what to make, how to pick, hints, remembered choices, editor defaults, tool stickiness) live in `ClearShotCore` with tests. The App adds a `CaptureBarView` inside the existing frozen-screen overlay, a full-screen pick mode, and a `CaptureLauncher` that runs the overlay and hands the result to the existing coordinators. Shortcuts keep their direct paths; only the menu and the new bar shortcut go through the launcher.

**Tech Stack:** Swift 6, SwiftUI, AppKit, ScreenCaptureKit, KeyboardShortcuts 3.1.0, Swift Testing. Build with `make build`; Core tests with `swift test --package-path Packages/ClearShotCore`.

**Spec:** `docs/superpowers/specs/2026-10-22-capture-bar-and-editor-tools-design.md`

## Global Constraints

- macOS 26, Swift 6 strict concurrency, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` in the App target.
- Every existing shortcut name and default key stays: `captureArea` ⌃⇧A, `captureWindow` ⌃⇧W, `captureFullScreen` ⌃⇧F, `scrollingCapture` ⌃⇧S, `scrollingWindow` ⌃⌥⇧S, `scrollingFullScreen` ⌃⇧⌘S, `recordScreen` ⌃⇧R, `recordWindow` ⌃⌥⇧R, `recordFullScreen` ⌃⇧⌘R, `pauseRecording` ⌃⇧P.
- New shortcut name `captureBar`, no default key. "Use the macOS shortcuts": ⇧⌘3 → `captureFullScreen`, ⇧⌘4 → `captureArea`, ⇧⌘5 → `captureBar`.
- Bar copy: groups "Screenshot · Scrolling · Record" and "Area · Window · Full screen"; hints "Drag an area", "Click a window", "Click a screen".
- Editor: `Annotation.Style.defaultWidth = 10`; `StyleValues.fontSize = 24`; `StyleValues.fontSizes = [12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 96, 128]`; `Bubble` default `fontSize = 24`; highlighter width stays 32.
- Commit messages follow the log: `core:`, `feat:`, `docs:`; trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Straight to `main`.

## Review Focus

1. A click on a bar button over the area overlay must not start a drag underneath — pinned by the live check (Task 6), not a unit test.
2. Full-screen pick with two displays: the clicked screen is captured, not the one under the mouse when the bar opened — live check with two screens if available.
3. Space in Full screen mode goes to Area (Task 4 keeps the toggle `area ↔ window`, `fullScreen → area`); covered by `CaptureBarModelTests.spaceTogglesAreaAndWindowAndLeavesFullScreenForArea` (Task 3).
4. The bar shortcut while a recording or a scrolling capture runs does nothing (`CaptureLauncher.open` guard, Task 5) — live check.
5. "Use the macOS shortcuts" when ⇧⌘5 was already Window: Window is reset to ⌃⇧W so one key never fires two actions (Task 5).

---

### Task 1: Editor defaults

**Files:**
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Editor/Annotation.swift` (`Style.defaultWidth`)
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Editor/Style.swift` (`fontSize`, `fontSizes`, comments)
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Editor/Figures.swift` (`Bubble.init` default)
- Test: `Packages/ClearShotCore/Tests/ClearShotCoreTests/StyleTests.swift`, `FigureTests.swift`, `EditorSessionTests.swift`

**Interfaces:**
- Produces: `Annotation.Style.defaultWidth == 10`, `StyleValues().fontSize == 24`, `StyleValues.fontSizes` (16 values), `Bubble(rect:tail:).fontSize == 24`.

- [ ] **Step 1: Write the failing tests**

In `StyleTests`:

```swift
@Test func newShapesAreTenPixelsWideAndTextIsTwentyFour() {
    #expect(Annotation.Style.defaultWidth == 10)
    #expect(StyleValues().width == 10 && StyleValues().fontSize == 24)
    #expect(StyleValues.fontSizes == [12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 96, 128])
    #expect(StyleValues.highlighter.width == 32)
}
```

In `FigureTests`, change `#expect(bubble.fontSize == 32)` (line 106) to `== 24`. In `EditorSessionTests`, change `plain?.fontSize == 32` (line 60) to `== 24` and `s.shownValues.width == 4` (line 264) to `== 10`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/ClearShotCore --filter "StyleTests|FigureTests|EditorSessionTests"`
Expected: the new test and the three changed assertions fail on 4 / 32.

- [ ] **Step 3: Change the defaults**

`defaultWidth: CGFloat = 10`; `fontSize: CGFloat = 24` with its comment ("24 px reads as 12 pt on a 2× screen, a normal label"); `fontSizes` as above; `Bubble.init(..., fontSize: CGFloat = 24)`.

- [ ] **Step 4: Run the whole Core suite**

Run: `swift test --package-path Packages/ClearShotCore`
Expected: all pass.

- [ ] **Step 5: Commit**

`core: shapes start 10 px wide, text and bubbles at 24, more text sizes`

### Task 2: Sticky tools

**Files:**
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Editor/EditorTool.swift` (remove `staysActive`; hint for `.select`)
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Editor/EditorSession.swift` (`dragEnded`, `placeText`, remove `handBackIfSingleUse`)
- Modify: `ClearShot/Editor/EditorCanvasView.swift` (`NSCursor.for(.move)` → `.arrow`)
- Modify: `README.md` (editor bullets)
- Test: `Packages/ClearShotCore/Tests/ClearShotCoreTests/EditorToolTests.swift`, `EditorSessionTests.swift`

**Interfaces:**
- Consumes: `EditorSession.tool`, `dragChanged/dragEnded`, `cancel()`.
- Produces: no `EditorTool.staysActive`; a drawing tool stays set after `dragEnded` and after a plain click.

- [ ] **Step 1: Write the failing tests**

In `EditorSessionTests`:
- Rename `shapeToolsHandBackToSelectButStrokesStepAndBlurStayOn` → `everyToolStaysOnAfterUse`: one loop over `[.line, .arrow, .rect, .ellipse, .bubble, .pen, .highlight, .step, .blur]`, drag, `finishTextEditing()`, `#expect(s.tool == tool)`; plus `.text`: `drag(s, p(10, 10))`, `s.editText("Hi")`, `s.finishTextEditing()`, `#expect(s.tool == .text)`.
- Rename `aClickWithADrawingToolAddsNothingAndHandsBackToThePointer` → `aClickWithADrawingToolAddsNothingAndKeepsTheTool`: drop `.crop` from the list (Crop keeps today's behaviour), assert `s.tool == tool`.
- `drawingAnArrowAddsOneSelectedUndoableArrow`: `#expect(s.tool == .arrow)`.
- Rename `clickingAwayFromAPenStrokeDeselectsItAndHandsBackToThePointer` → `clickingAwayFromAPenStrokeDeselectsItAndKeepsThePen`: final assertion `s.tool == .pen`.
- New `aPlainClickKeepsTheToolAndClearsTheSelection`: `s.tool = .rect`; drag a rect; `#expect(s.document.selection.count == 1)`; `drag(s, p(300, 250))` (a click on empty space); `#expect(s.document.selection.isEmpty && s.tool == .rect && s.document.annotations.count == 1)`.
- New `escapeGoesBackToSelect`: `s.tool = .rect`; `s.cancel()`; `#expect(s.tool == .select)`.
- Check lines 232, 277, 297, 309, 319 (`s.tool == .select`): keep the ones about Crop and Esc; change those that only followed a drawing tool to the tool itself.

In `EditorToolTests`: delete `strokesAndCropNeverGrabExistingShapes`? No, keep it. Nothing else.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/ClearShotCore --filter EditorSessionTests`
Expected: the renamed and new tests fail with `tool == .select`.

- [ ] **Step 3: Make tools sticky**

- `EditorTool`: delete `staysActive` and its doc comment.
- `EditorSession`: delete `handBackIfSingleUse()` and both calls; in `dragEnded`, the too-small branch keeps the tool (`document.revert(); document.selection = []`), the crop branch is unchanged.
- `EditorTool.hint` for `.select`: unchanged. Add to each drawing tool's hint nothing; instead the README explains.

- [ ] **Step 4: Run the whole Core suite**

Run: `swift test --package-path Packages/ClearShotCore`
Expected: all pass.

- [ ] **Step 5: Cursor and README**

- `ClearShot/Editor/EditorCanvasView.swift`: `case .move: .arrow` (was `.openHand`).
- `README.md`: replace "Shape and text tools hand back to the pointer after one use, so you can adjust right away. Pen, Highlighter, Step and Blur stay on; a plain click with any tool goes back to the pointer." with "A tool stays on until you press Esc or pick Select, so you can draw several shapes in a row. The shape you just drew stays selected, so colour and width changes apply to it. Over an existing shape the pointer takes over: drag to move it, drag a dot to resize it."
- Also the editor table rows for Text and Speech bubble, if they say the size.

- [ ] **Step 6: Build the app**

Run: `make build`
Expected: exit 0.

- [ ] **Step 7: Commit**

`feat: tools stay on after use; the pointer takes over above a shape`

### Task 3: Core — capture action, pick mode, remembered choices

**Files:**
- Create: `Packages/ClearShotCore/Sources/ClearShotCore/Capture/CaptureAction.swift`
- Create: `Packages/ClearShotCore/Sources/ClearShotCore/Capture/PickMode.swift`
- Create: `Packages/ClearShotCore/Sources/ClearShotCore/Capture/CaptureBarModel.swift`
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Settings/AppSettings.swift` (two keys, two vars)
- Test: `Packages/ClearShotCore/Tests/ClearShotCoreTests/CaptureBarModelTests.swift` (new), `AppSettingsTests.swift`

**Interfaces:**
- Produces:
  - `public enum CaptureAction: String, CaseIterable, Sendable, Codable { case screenshot, scrolling, recording; var title: String; var symbol: String }` — titles "Screenshot", "Scrolling", "Record"; symbols "camera.viewfinder", "arrow.up.and.down", "record.circle".
  - `public enum PickMode: String, CaseIterable, Sendable, Codable { case area, window, fullScreen; var title: String; var symbol: String; var hint: String; var kind: CaptureKind; var afterSpace: PickMode }` — titles "Area", "Window", "Full screen"; symbols "rectangle.dashed", "macwindow", "display"; hints "Drag an area", "Click a window", "Click a screen"; `kind`: `.area → .area`, `.window → .window`, `.fullScreen → .fullScreen`; `afterSpace`: `.area → .window`, `.window → .area`, `.fullScreen → .area`.
  - `@Observable public final class CaptureBarModel { public var action: CaptureAction; public var pickMode: PickMode; public var hint: String { pickMode.hint }; public init(action: CaptureAction, pickMode: PickMode); public static func remembered(from settings: AppSettings, action: CaptureAction?) -> CaptureBarModel; public func remember(in settings: AppSettings) }`.
  - `AppSettings.lastCaptureAction: CaptureAction` (default `.screenshot`, key `"lastCaptureAction"`), `AppSettings.lastPickMode: PickMode` (default `.area`, key `"lastPickMode"`).

- [ ] **Step 1: Write the failing tests**

`CaptureBarModelTests`:

```swift
@Test func eachPickModeSaysWhatToDoAndWhatItMakes() {
    #expect(PickMode.area.hint == "Drag an area" && PickMode.window.hint == "Click a window" && PickMode.fullScreen.hint == "Click a screen")
    #expect(PickMode.area.kind == .area && PickMode.window.kind == .window && PickMode.fullScreen.kind == .fullScreen)
    #expect(CaptureAction.allCases.allSatisfy { !$0.title.isEmpty && !$0.symbol.isEmpty })
    #expect(PickMode.allCases.allSatisfy { !$0.title.isEmpty && !$0.symbol.isEmpty })
}

@Test func spaceTogglesAreaAndWindowAndLeavesFullScreenForArea() {
    #expect(PickMode.area.afterSpace == .window && PickMode.window.afterSpace == .area && PickMode.fullScreen.afterSpace == .area)
}

@Test func theBarRemembersWhatAndHowBetweenUses() {
    let (defaults, cleanup) = freshDefaults(); defer { cleanup() }   // same helper as AppSettingsTests, copied locally
    let settings = AppSettings(defaults: defaults)
    let first = CaptureBarModel.remembered(from: settings, action: .recording)
    #expect(first.action == .recording && first.pickMode == .area)
    first.pickMode = .fullScreen
    first.remember(in: settings)
    let next = CaptureBarModel.remembered(from: settings, action: nil)
    #expect(next.action == .recording && next.pickMode == .fullScreen)
    #expect(CaptureBarModel.remembered(from: settings, action: .screenshot).action == .screenshot)
}
```

`AppSettingsTests.defaultsMatchSpec`: add `#expect(settings.lastCaptureAction == .screenshot && settings.lastPickMode == .area)`. In the persistence test (find the one that writes and reads back), add `settings.lastPickMode = .window` and read it back from a second `AppSettings(defaults:)`.

- [ ] **Step 2: Run to verify they fail**

Run: `swift test --package-path Packages/ClearShotCore --filter "CaptureBarModelTests|AppSettingsTests"`
Expected: compile errors on the missing types.

- [ ] **Step 3: Implement the three files and the two settings**

Settings follow the existing pattern: `defaults.string(forKey:).flatMap(PickMode.init(rawValue:)) ?? .area`, `didSet { defaults.set(rawValue, forKey:) }`.

- [ ] **Step 4: Run the whole Core suite**

Expected: all pass.

- [ ] **Step 5: Commit**

`core: what to capture and how to pick it, remembered for the capture bar`

### Task 4: App — pick modes in the overlay and the bar view

**Files:**
- Modify: `ClearShot/Capture/OverlayState.swift` — `init(bar: CaptureBarModel, showsBar: Bool)`; `let bar`, `let showsBar`, `var windows`; `var pickMode: PickMode { get set }` forwarding to `bar.pickMode`.
- Modify: `ClearShot/Capture/OverlayCaptureSession.swift` — delete `enum Mode`; `Outcome` gains `case fullScreen(CGImage, ScreenRegion)`; `static func run(bar: CaptureBarModel, showsBar: Bool, settings: AppSettings) async throws -> Outcome` and `static func run(mode: PickMode, settings: AppSettings) async throws -> Outcome` (the old picker: `bar = CaptureBarModel(action: .screenshot, pickMode: mode)`, `showsBar: false`); `panel.onToggleMode = { state.pickMode = state.pickMode.afterSpace }`; the bar is passed to the overlay view of the screen under the mouse only (`showsBar: state.showsBar && screen.frame.contains(mouse)`), with `bottomInset: screen.visibleFrame.minY - screen.frame.minY + ToolbarPanel.bottomGap`; a new `onPickFullScreen` closure per screen resolves `.fullScreen(image, region)` where `region = ScreenRegion(displayID: screen.displayID ?? 0, quartzRect: quartzFrame, scale: screen.backingScaleFactor)`.
- Modify: `ClearShot/Capture/CaptureOverlayView.swift` — `switch state.pickMode`: `.area` → `SelectionOverlayView`, `.window` → `WindowPickOverlayView`, `.fullScreen` → new `FullScreenPickOverlayView(frozen:onPick:)`; `.overlay(alignment: .bottom) { if showsBar { CaptureBarView(model: state.bar, onCancel: onCancel).padding(.bottom, bottomInset) } }`.
- Create: `ClearShot/Capture/FullScreenPickOverlayView.swift` — the frozen image, a `DimLayer(size:hole:nil)` whose opacity is 0 while the mouse is over this view (`onContinuousHover`), `.onTapGesture { onPick() }`; cursor stays the crosshair.
- Create: `ClearShot/Capture/CaptureBarView.swift` — `struct CaptureBarView: View { let model: CaptureBarModel; let onCancel: () -> Void }`: `ToolbarCapsule { ToolbarCloseButton("Cancel (Esc)"); ToolbarSeparator; ForEach(CaptureAction.allCases) OptionChip(title:symbol:isOn: model.action == $0, help: "Make a \($0.title.lowercased())") { model.action = $0 }; ToolbarSeparator; ForEach(PickMode.allCases) OptionChip(...) { model.pickMode = $0 }; ToolbarSeparator; Text(model.hint).font(.callout).foregroundStyle(.secondary).padding(.trailing, 6) }`.
- Modify: `ClearShot/Capture/RegionPicker.swift` — `OverlayCaptureSession.run(mode: kind == .window ? .window : .area, settings:)`; add `static func target(from outcome: OverlayCaptureSession.Outcome) async throws -> Target?` (`.area(_, region)` → `Target(region, nil)`; `.window(w)` → `Target(try await spot(of: w), w)`; `.fullScreen(_, region)` → `Target(region, nil)`; `.cancelled` → nil) and make `pick` use it.
- Modify: `ClearShot/Capture/CaptureCoordinator.swift` — `makeCapture` calls `run(mode:)`; extract `func capture(from outcome: OverlayCaptureSession.Outcome) async throws -> Capture?` (area, window with the double shot, fullScreen → `Capture(kind: .fullScreen, image:)`, cancelled → nil) and use it from `makeCapture`.

**Interfaces:**
- Consumes: `CaptureBarModel`, `PickMode`, `CaptureAction` (Task 3); `ToolbarCapsule`, `OptionChip`, `ToolbarCloseButton`, `ToolbarSeparator` (`ToolbarPanel.swift`).
- Produces: `OverlayCaptureSession.run(bar:showsBar:settings:)`, `Outcome.fullScreen`, `RegionPicker.target(from:)`, `CaptureCoordinator.capture(from:)`.

- [ ] **Step 1: Make the changes above** (no Core tests cover the App; the build is the check)

- [ ] **Step 2: Build**

Run: `make build`
Expected: exit 0. Existing flows (⌃⇧A etc.) must behave as before: they call `run(mode:)` with no bar.

- [ ] **Step 3: Commit**

`feat: the capture overlay can pick a whole screen and show the capture bar`

### Task 5: App — the launcher, menu, shortcut and settings

**Files:**
- Create: `ClearShot/Capture/CaptureLauncher.swift` — `@Observable @MainActor final class CaptureLauncher { init(settings:, captures: CaptureCoordinator, recording: RecordingCoordinator, scrolling: ScrollingCoordinator, onPermissionMissing:); private(set) var isOpen = false; func open(_ action: CaptureAction?) }`. `open`: guard screen-recording permission (else `onPermissionMissing()`), guard `!isOpen`, `recording.state == .idle`, `scrolling.state == .idle`; `let bar = CaptureBarModel.remembered(from: settings, action: action)`; `isOpen = true`; `Task { defer { isOpen = false }; let outcome = try await OverlayCaptureSession.run(bar: bar, showsBar: true, settings: settings); bar.remember(in: settings); switch bar.action { case .screenshot: captures.deliver(outcome); case .scrolling: if let target = try await RegionPicker.target(from: outcome) { scrolling.start(with: target, kind: bar.pickMode.kind) }; case .recording: if let target = ... { recording.start(with: target.region, kind: bar.pickMode.kind) } }` with `DiagnosticLog` lines "capture bar opened on <action>" and "capture bar cancelled"; errors go to `ErrorPresenter.show(title: "Capture failed", ...)`.
- Modify: `ClearShot/Capture/CaptureCoordinator.swift` — `func deliver(_ outcome: OverlayCaptureSession.Outcome)`: same guard/Task shape as `capture(_:)`, calling `capture(from:)` then `finish`.
- Modify: `ClearShot/Recording/RecordingCoordinator.swift` — `func start(with region: ScreenRegion, kind: CaptureKind)`: permission guard, `guard state == .idle`, `self.kind = kind`, `self.region = region`, `showToolbar(for: region)`, log "record(kind) from the bar".
- Modify: `ClearShot/Scrolling/ScrollingCoordinator.swift` — `func start(with target: RegionPicker.Target, kind: CaptureKind)`: same shape, `toolbarModel.mode = .manual`, `self.target = target`, `showToolbar(for: target.region)`.
- Modify: `ClearShot/Services/HotkeyService.swift` — `static let captureBar = Self("captureBar")`; `init` takes `launcher: CaptureLauncher`; `KeyboardShortcuts.onKeyUp(for: .captureBar) { [launcher] in launcher.open(nil) }`.
- Modify: `ClearShot/App/AppDelegate.swift` — `private(set) lazy var launcher = CaptureLauncher(...)`; pass it to `HotkeyService`.
- Modify: `ClearShot/App/ClearShotApp.swift` — `.environment(appDelegate.launcher)` on the menu.
- Modify: `ClearShot/App/MenuBarMenu.swift` — `@Environment(CaptureLauncher.self) private var launcher`; replace the three `kind(...)` calls with `item("Screenshot", "camera.viewfinder") { launcher.open(.screenshot) }`, `item("Scrolling Capture", "arrow.up.and.down") { launcher.open(.scrolling) }.disabled(scrolling.state != .idle)`, `item("Record", "record.circle") { launcher.open(.recording) }.disabled(recording.state != .idle)`; delete `kind(_:_:area:window:fullScreen:)` and `Choice`; update the type's doc comment.
- Modify: `ClearShot/Settings/SettingsView.swift` — new first `Section { KeyboardShortcuts.Recorder("Open the capture bar", name: .captureBar) } header: { Text("Capture bar") } footer: { Text("Pick what to make and how, like the macOS ⇧⌘5 bar. Screenshot, Scrolling Capture and Record in the menu open it too.") }`; `useSystemShortcuts()`: ⇧⌘5 → `.captureBar`, and first `if KeyboardShortcuts.getShortcut(for: .captureWindow) == .init(.five, modifiers: [.shift, .command]) { KeyboardShortcuts.reset(.captureWindow) }`; footer text: "…⇧⌘3 (full screen), ⇧⌘4 (area) and ⇧⌘5 (the capture bar)."

**Interfaces:**
- Consumes: Task 4's `run(bar:showsBar:settings:)`, `RegionPicker.target(from:)`, `CaptureCoordinator.capture(from:)`; Task 3's model.
- Produces: `CaptureLauncher.open(_:)`, `RecordingCoordinator.start(with:kind:)`, `ScrollingCoordinator.start(with:kind:)`, `KeyboardShortcuts.Name.captureBar`.

- [ ] **Step 1: Make the changes above**
- [ ] **Step 2: Build** — `make build`, exit 0.
- [ ] **Step 3: Commit** — `feat: one capture bar from the menu and ⇧⌘5: what to make, how to pick`

### Task 6: Docs and live check

**Files:**
- Modify: `README.md` — Capture section: a new first bullet "**The bar** — **Screenshot**, **Scrolling Capture** or **Record** in the menu freezes the screen and shows a bar at the bottom: pick what to make and how (Area, Window or Full screen), then drag, click a window or click a screen. Space switches Area and Window, Esc cancels. Give it a key in Settings → Shortcuts; **Use the macOS shortcuts** makes it ⇧⌘5, like the Mac's own bar."; lines 60 and 65 ("… ▸ Area / Window / Full Screen in the menu" → "… in the menu (then pick on the bar)"); the shortcuts table gets a row "Anywhere | (none, set it) | Open the capture bar"; the Settings bullet (line 110) ends "⇧⌘5 opens the capture bar".
- Modify: the spec — append "## What changed while building" if anything did.

- [ ] **Step 1: Edit the README and the spec**
- [ ] **Step 2: Run everything** — `swift test --package-path Packages/ClearShotCore` (all pass) and `make build` (exit 0).
- [ ] **Step 3: Commit** — `docs: the capture bar, sticky tools and the new defaults`
- [ ] **Step 4: Live check by Austin** — the list at the end of the spec. Not automated.
