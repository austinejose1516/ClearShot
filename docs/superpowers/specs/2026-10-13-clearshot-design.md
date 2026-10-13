# ClearShot — implementation plan

## Context

Austin wants a native Mac screenshot app, like CleanShot X, but screenshots only (no video).

- After a capture, a rounded card stays at the bottom of the screen with Edit, Close, and a few more actions.
- Edit opens a full editor: lines, curvy lines, thickness, text, boxed text, captions, padding, background, insets, fun extras.
- Built with the latest Mac tech. Personal use for now. Xcode is not installed yet.

**Decisions already made with Austin:**

| Topic | Decision |
|---|---|
| Build tool | Install Xcode first. Use a normal Xcode project. |
| Users | Only Austin for now. No paid Apple Developer account. |
| Capture modes | Area, Window, Full screen. Scrolling capture is out of v1. |
| Fun extras | Emoji stickers, speech bubbles, blur/pixelate, meme caption bar. |

**Decisions I made (change any of them):**

| Topic | Decision | Why |
|---|---|---|
| Project path | `~/Development/Personal/clearshot` | Next to your other personal projects. |
| App name / bundle id | `ClearShot` / `com.austinejose.clearshot` | |
| Language / UI | Swift 6, SwiftUI for views, AppKit for windows and panels | SwiftUI alone cannot make floating panels or full-screen overlays. |
| Capture API | ScreenCaptureKit `SCScreenshotManager` (new macOS 26 screenshot API) | Confirmed in the macOS 27 SDK on this Mac. Clean images, window shadows optional. |
| Minimum macOS | 26.0 | All APIs we use exist from 26. Keeps it working on Tahoe too. |
| Project file | XcodeGen (`project.yml` → generates `.xcodeproj`) | The project file is text, so I can edit it. Generated `.xcodeproj` is git-ignored. |
| Signing | Xcode "Personal Team" (free, your Apple ID) | Ad-hoc signing changes on every build, so macOS asks for Screen Recording permission again each time. A Personal Team certificate is stable. |
| Sandbox | Off | Not needed outside the App Store. Makes saving to any folder simple. |
| Global hotkeys | `KeyboardShortcuts` Swift package (by sindresorhus) | Gives a shortcut recorder in Settings for free. Fallback: Carbon `RegisterEventHotKey` (confirmed in SDK). |
| Default hotkeys | ⌃⇧A area, ⌃⇧W window, ⌃⇧F full screen | No clash with macOS ⇧⌘3/4/5. Editable in Settings. |
| Save location | `~/Pictures/ClearShot/` as PNG, also copied to clipboard | Same as CleanShot defaults. Editable in Settings. |
| Editor Save | Overwrites the capture file. "Export As…" writes a new file. | Same as CleanShot. |
| Tests | Swift Testing (`import Testing`) for pure logic. Manual checks for UI. | |

**Approaches I did not pick:**

- Electron or Tauri with a web canvas. Easier editor libraries, but floating panels, capture overlays, and permissions are clunky. Not a "latest Mac" feel.
- Native Swift but use the `screencapture` command for the selection UI. Fastest start, but we cannot style the overlay or show window hover highlights. Kept as a fallback if the custom overlay is hard.

## Prerequisites (Austin does these)

1. Install Xcode from the App Store (about 15 GB). Open it once so it installs its components.
2. Run in a terminal:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
3. Xcode → Settings → Accounts → add your Apple ID. This creates the free Personal Team for signing.
4. Tell me when done. I will then run `brew install xcodegen` and start Phase 1.

## Architecture

Six small parts. Each has one job.

```text
Hotkey / menu  ──▶  CaptureSession  ──▶  Capture (image + file)  ──▶  QuickAccessPanel (card at bottom)
                         │                                                    │ Edit
                   SelectionOverlay                                           ▼
                   (one per screen)                                   EditorWindow (EditorDocument)
                                                                              │ Save / Copy
                                                                              ▼
                                                                      Exporter (ImageRenderer)
```

### 1. App shell — `ClearShot/App/`

- `ClearShotApp.swift`: SwiftUI `App`. `MenuBarExtra` menu (Capture Area / Window / Full Screen, Settings, Quit). `Settings` scene. `WindowGroup(for: Capture.ID.self)` for editor windows, one per capture.
- `AppDelegate.swift`: registers hotkeys, runs first-launch permission check. `LSUIElement = YES` in Info.plist (menu bar only, no Dock icon).

### 2. Capture — `ClearShot/Capture/`

- `ScreenCapturer.swift` (actor): thin wrapper over ScreenCaptureKit. `captureDisplay(_:)`, `captureWindow(_:withShadow:)`, `shareableContent()`. Excludes our own windows via `SCContentFilter(display:excludingApplications:)`. SDR output only.
- `CaptureSession.swift` (@MainActor): runs one capture. Steps: snapshot every display → open one `SelectionOverlayWindow` per screen → wait for result (rect, window, or cancel) → crop → make `Capture` → save file, copy to clipboard, play sound → show card.
- `SelectionOverlayWindow.swift`: borderless `NSWindow`, level `.screenSaver`, covers the screen, crosshair cursor, Esc cancels.
- `SelectionOverlayView.swift` (SwiftUI): shows the frozen display image dimmed. Drag draws a rectangle with a size label. Space toggles to window mode (hover highlights the window under the cursor). Click or Enter confirms.
- `SelectionGeometry.swift` (pure struct, tested): rect normalising, points → pixels using the screen scale, window hit-testing front to back, ScreenCaptureKit (top-left origin) → AppKit (bottom-left origin) coordinate conversion.
- `WindowPicker.swift`: filters `SCShareableContent.windows` to on-screen, normal-layer, not ours.

### 3. Capture store and files — `ClearShot/Model/`, `ClearShot/Services/`

- `Capture.swift`: id, `CGImage`, created date, kind (area/window/full), file URL.
- `CaptureStore.swift` (@Observable): recent captures in memory.
- `FileSaver.swift`: writes PNG/JPEG with `CGImageDestination`. `FileNamer` (tested) makes names like `ClearShot 2026-10-13 at 09.41.12.png`.
- `ClipboardService.swift`: writes PNG + TIFF to `NSPasteboard`.
- `SettingsStore.swift` (@Observable, backed by UserDefaults): save folder, format, copy to clipboard, show cursor, card auto-close seconds, play sound, launch at login (`SMAppService`).
- `PermissionService.swift`: `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`, and a button that opens System Settings → Screen Recording. Onboarding window shown when permission is missing.

### 4. Quick Access card — `ClearShot/Overlay/`

- `QuickAccessPanel.swift`: `NSPanel` (non-activating, borderless, floating level, joins all Spaces, stays during full-screen apps, transparent). One panel per card.
- `QuickAccessController.swift`: keeps the list of open cards. Places cards bottom-left of the screen where the capture happened, 16 pt margin, newest on the left, side by side. Re-lays out when one closes. Optional auto-close timer.
- `QuickAccessView.swift` (SwiftUI): rounded 16 pt card with Liquid Glass (`.glassEffect`, the macOS 26 frosted look). Thumbnail. Hover shows the toolbar: **Edit**, **Copy**, **Reveal in Finder**, **Close**. Drag the thumbnail out to drop the file into Finder, Slack, etc. Slide-up and fade animations.

### 5. Editor — `ClearShot/Editor/`

- `EditorDocument.swift` (@Observable): `baseImage`, `annotations`, `frame`, `crop`, `selection`, undo/redo. Undo is snapshot based: `UndoStack<DocumentState>` (tested) stores copies of a value-type `DocumentState`. Simple and safe with small data.
- `Annotation.swift` (struct, Codable). Coordinates are in **image pixels**, so edits survive padding and inset changes.
  - Kinds: `line` (optional arrowheads), `freehand` (curvy pen), `rect`, `ellipse`, `text` (with `boxed` flag → filled rounded box behind the text), `speechBubble` (rect + draggable tail point + text), `emoji` (character, centre, size, rotation), `blur` (rect, mode blur or pixelate), `step` (numbered circle).
  - `Style`: stroke colour, stroke width, fill colour, font size, text colour.
- `FrameStyle.swift`: `padding` (adds space around the image, canvas grows), `inset` (shrinks the image inside the original size, canvas stays), `cornerRadius`, `shadow`, `background` (none / solid / gradient preset / image file), `caption` (one text line under the image, inside the frame), `meme` (top text, bottom text, white bars, bold Impact-style font).
- `CanvasLayout.swift` (pure struct, tested): from image size + frame + crop → canvas size, image rect, caption rect, meme bar rects. Converts image pixels ⇄ canvas points.
- `CompositionView.swift` (SwiftUI): draws background → image (cropped, rounded, shadow, inset) → annotations → caption and meme bars. **This one view is used both on screen and for export**, so what you see is what you get.
  - `AnnotationView.swift` switches on kind. `PathSmoother.swift` (tested) turns freehand points into a smooth curve (Catmull-Rom → Bézier). `SpeechBubbleShape.swift`. `BlurRegionView.swift` crops the base image and applies `CIPixellate` / `CIGaussianBlur`.
- `EditorCanvasView.swift`: `CompositionView` + an interaction layer on top: selection handles (8 handles), drag to move, Delete, arrow keys to nudge. For text, corner drag scales the font size and side drag changes the wrap width.
- `Tools/`: one file per tool, all follow protocol `EditorTool { begin(at:) / update(to:) / end() }`. Tools: Select, Line, Arrow, Pen, Rect, Ellipse, Text, BoxedText, SpeechBubble, Emoji, Blur, Step, Crop.
- `EditorView.swift`: toolbar (tools), zoomable canvas, right inspector (`InspectorView.swift`: stroke width, colour, font size, arrowheads, fill), frame panel (`FramePanelView.swift`: padding, inset, radius, shadow, background picker, caption, meme text). Shortcuts: ⌘Z / ⇧⌘Z, ⌘C copy export, ⌘S save, ⌘A, Esc.
- `Exporter.swift`: `ImageRenderer(content: CompositionView(forExport: true))` at the image's scale (2× on Retina) → `CGImage` → `FileSaver` / `ClipboardService` / `NSSavePanel`.
- `EditorSessionStore.swift`: keeps one `EditorDocument` per capture id, so reopening Edit keeps your edits.

### 6. Project files

```text
clearshot/
  project.yml            # XcodeGen spec: app target, test target, KeyboardShortcuts package
  Local.xcconfig         # DEVELOPMENT_TEAM=<your personal team>  (git-ignored)
  Makefile               # make gen / build / test / run
  ClearShot/          # App, Capture, Overlay, Editor, Model, Services, Resources (Assets.xcassets, gradients)
  ClearShot/Info.plist
  ClearShotTests/     # Swift Testing
  .gitignore             # *.xcodeproj, Local.xcconfig, build/
```

## Phases

Each phase ends with a build that runs. I stop after each phase and show you.

| # | Phase | What you can check | Size |
|---|---|---|---|
| 1 | Skeleton | Menu bar icon. Settings window opens. Permission onboarding shows. Hotkeys print a log line. | S |
| 2 | Full-screen capture | Press ⌃⇧F → PNG lands in `~/Pictures/ClearShot/`, also on clipboard, shutter sound. | S |
| 3 | Area capture | ⌃⇧A → screen freezes and dims → drag → size label → Esc cancels. Retina file is 2× pixel size. | M |
| 4 | Window capture | ⌃⇧W → hover highlights windows → click captures with shadow. Space toggles area/window. | M |
| 5 | Quick Access card | Card at bottom-left after every capture. Edit, Copy, Reveal, Close, drag out. Stacking. Auto-close setting. | M |
| 6 | Editor core | Editor window. Select / move / resize / delete. Undo/redo. Line, Arrow, Pen, Rect, Ellipse. Thickness and colour. Save and Copy. | L |
| 7 | Text | Text, boxed text, resize text with handles, caption under image, meme bar top/bottom. | M |
| 8 | Frame | Padding, inset, corner radius, shadow, backgrounds (solid, 8 gradient presets, your own image). Live preview. | M |
| 9 | Fun and privacy | Emoji stickers (resize, rotate), speech bubbles with draggable tail, blur/pixelate, step numbers. | M |
| 10 | Polish | App icon, crop tool, launch at login, error alerts (no permission, save failed), empty states. | S |

S = under half a day. M = about a day. L = one to two days. Phases 1–5 together is roughly two days. Phases 6–9 is roughly four days.

## Verification

- **Build and tests, every phase:**
  ```bash
  make gen && make build && make test
  # = xcodegen generate; xcodebuild -scheme ClearShot -destination 'platform=macOS' build / test
  ```
- **Unit tests** (Swift Testing) for the pure parts: `SelectionGeometry`, `CanvasLayout`, `PathSmoother`, `UndoStack`, `FileNamer`, and `Exporter` output size (padding 40 on a 1200×800 image → 1280×880 file; inset keeps 1200×800).
- **Manual checks**, end to end: hotkey → overlay → selection → file on disk and clipboard → card at bottom → Edit → draw, text, frame → Save → open the PNG in Preview and compare to the editor.
- **Permission check:** rebuild the app three times. Screen Recording must not be asked again (proves Personal Team signing works).
- I can drive the app with the computer-use tools on this Mac to take screenshots of each phase for you.

## Risks and things I am not certain about

- **macOS 27 details.** My knowledge stops at June 2026. I checked the main APIs in the SDK headers on this Mac. I will check each new API the same way before using it.
- **Window order and coordinates from ScreenCaptureKit.** Not certain the window list is front to back. Phase 4 will test it.
- **`KeyboardShortcuts` package with Swift 6 strict concurrency.** If it fails to build, I switch to a small Carbon hotkey wrapper (about 80 lines).
- **Export of blur regions through `ImageRenderer`.** The blur is baked to a `CGImage` first, so it should render. Phase 9 will confirm.
- **Screen Recording permission re-asked after builds.** Fixed by Personal Team signing. Fallback: a self-signed code-signing certificate in Keychain Access.

## Out of v1

Scrolling capture, OCR, cloud upload, capture history window, pin to screen, video or GIF.
