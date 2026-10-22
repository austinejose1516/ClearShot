# Video Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The screenshot editor's Frame panel (background, padding, corners, shadow) in the video editor, shown live and written on Done.

**Architecture:** Core adds `VideoEncoding.Settings.resized(to:)` and an `encoding` on `Capture.saved`. The App replaces `VideoBlurComposition` with a custom compositor (`VideoCompositor` + `VideoComposer`) that draws blur boxes and the frame for both the player and the exporter, generalizes `FramePanelView` over a `FrameEditing` protocol, and adds the panel, state and layout mapping to the video editor.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation (`AVVideoCompositing`), Core Image, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-22-video-frame-design.md`

## Global Constraints

- Output size = `CanvasLayout(imageSize: video, frame:).canvasSize` made even by `resized(to:)`; bitrate × (new pixels / old pixels), clamped to `VideoEncoding.minimumVideoBitrate…maximumVideoBitrate`; fps and audio unchanged.
- Shadow: colour black at `frame.shadowOpacity`, blur `frame.shadowRadius(canvasSize:)`, moved down by radius / 3. Background none → black. Gradient top-left → bottom-right. Image aspect-filled and centred.
- Pixel format BGRA in and out of the compositor.
- Copy: "Frame" switch; panel unchanged.
- Commits: `core:`, `feat:`, `docs:`, `release: 0.12.0`, `packaging: cask 0.12.0`, tap `clearshot 0.12.0`; trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. Padding that makes an odd canvas (e.g. 1921): the writer and the render size agree (both even) — `VideoEncodingTests.resizedKeepsSidesEven` (Task 1).
2. A huge padding on a big video must not exceed the bitrate ceiling — `resizedClampsTheBitrate` (Task 1).
3. Frame on, no boxes, no trim: Done still exports (`hasEdits` includes the frame) — Task 3, live.
4. Edit again after a framed save: the editor opens at the new size (`Capture.saved(... encoding:)`) — `CaptureTests.savingAVideoCanChangeItsSize` (Task 1).
5. Blur box drawn with the frame on lands on the video, not the padding — overlay mapping through `CanvasLayout.imageRect` (Task 3), live.

---

### Task 1: Core — resized settings, saved encoding

**Files:**
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Video/VideoEncoding.swift`, `Packages/ClearShotCore/Sources/ClearShotCore/Capture/Capture.swift`
- Test: `Packages/ClearShotCore/Tests/ClearShotCoreTests/VideoEncodingTests.swift`, `CaptureTests.swift`

**Interfaces:**
- `extension VideoEncoding.Settings { public func resized(to size: CGSize) -> VideoEncoding.Settings }`
- `Capture.saved(videoDuration: Double, poster: CGImage, encoding: VideoEncoding.Settings? = nil, at url: URL)` — nil keeps the old encoding.

- [ ] Step 1: tests `resizedKeepsSidesEvenAndScalesTheBitrate`, `resizedClampsTheBitrate`, `savingAVideoCanChangeItsSize` (RED).
- [ ] Step 2: implement; run `swift test --filter "VideoEncodingTests|CaptureTests"` (GREEN).
- [ ] Step 3: commit `core: encoding settings at another size; a saved recording can change size`.

### Task 2: App — the compositor

**Files:**
- Delete: `ClearShot/Recording/VideoBlurComposition.swift`
- Create: `ClearShot/Recording/VideoComposer.swift` (`VideoComposer`: `Mutex` state of `blurs` + `frame`, cached plate; `render(_ source: CIImage, canvas: CGSize) -> CIImage`; `static func composition(for asset: AVAsset, composer:, renderSize:) async throws -> AVVideoComposition`), `ClearShot/Recording/VideoCompositor.swift` (`VideoComposerInstruction`, `VideoCompositor: AVVideoCompositing`)
- Modify: `ClearShot/Recording/VideoExporter.swift` (`blurs:` → `composer: VideoComposer?`, `renderSize`), `ClearShot/Recording/VideoWindowController.swift` (uses `VideoComposer`)

- [ ] Step 1: write the compositor and composer; exporter takes `edits: VideoEdits?` where `struct VideoEdits { blurs, frame }`… (ruling at execution: keep a single `VideoComposer` value).
- [ ] Step 2: `make build` clean; commit `feat: one compositor draws blur boxes and the frame for the player and the exporter`.

### Task 3: App — the Frame panel in the video editor

**Files:**
- Modify: `ClearShot/Editor/FramePanelView.swift` (`FrameEditing` protocol; `document: any FrameEditing`), `ClearShot/Editor/EditorView.swift` (call site unchanged if `EditorDocument: FrameEditing`), `ClearShot/Recording/VideoWindowController.swift` (`VideoState.frame`, `showsFramePanel`, layout, preview rebuild on size change, `hasEdits`, save result with `encoding`), `ClearShot/Recording/VideoView.swift` (Frame toggle, side panel), `ClearShot/Recording/VideoBlurOverlay.swift` (`layout: CanvasLayout`), `ClearShot/Recording/VideoEditorStore.swift` + `ClearShot/App/AppDelegate.swift` + `ClearShot/Overlay/QuickAccessController.swift` (`savedVideo` passes `encoding`), `README.md`

- [ ] Step 1: implement; `make build` clean; `swift test` green.
- [ ] Step 2: commit `feat: the Frame panel in the video editor: background, padding, corners and shadow on a recording`; `docs:` in the same commit or after.

### Task 4: Release 0.12.0 and upgrade

- [ ] bump `project.yml` (0.12.0 / 13), `make release`, push main + tag, `gh run watch`, cask + tap, notes, `brew upgrade --cask clearshot`, relaunch, confirm build 13.
