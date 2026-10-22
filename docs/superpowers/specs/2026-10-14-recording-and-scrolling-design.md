# ClearShot: screen recording and scrolling capture

> The approved design, 2026-10-14. See the end for what changed while building.

## Context

ClearShot takes screenshots (area, window, full screen), shows a Quick Access card, edits, saves to a folder (Desktop by default) and uploads to a Cloudflare R2 bucket. Two things are missing that CleanShot X users expect:

1. **Screen recording.** Record an area, a window or the full screen to a video. Then trim it, save it, share it or upload it. Files must stay small.
2. **Scrolling capture.** One tall screenshot of a long page, built by stitching frames while the page scrolls.

Decisions already made with Austin:

| Question | Answer |
|---|---|
| Recording modes | Area, Window, Full screen |
| Sound | Microphone + system audio, mixed into one track |
| Scrolling | App scrolls for you when Accessibility is allowed; you scroll by hand otherwise |
| When is a video saved | Only on Save / Save As (Upload and Share export to a temp file). Nothing lands on disk until then |

Why files stay small: record at 1x (not Retina 2x), 30 fps, H.264 (plays in every browser), with a bitrate we compute from the pixel count. A 1-minute recording of normal UI work lands in the 3–15 MB range. QuickTime's own recording of the same is 100 MB+.

## Architecture

Same split as today: pure logic in `Packages/ClearShotCore` (tested with `swift test`), AppKit/SwiftUI/ScreenCaptureKit/AVFoundation in the app target.

```text
Hotkey ⌃⇧R / menu ─▶ RecordingCoordinator ─▶ OverlayCaptureSession (area/window) ─▶ ScreenRecorder (SCStream + SCRecordingOutput → temp .mp4)
                                              │                                        │
                                              └─ RecordingBarPanel (red dot, time, Stop) ◀┘
                                                              │ stop
                                                              ▼
                                            VideoWindowController (player, trim bar, Save / Save As / Share / Upload)
                                                              │
                                                              ▼
                                            VideoExporter (AVAssetReader → AVAssetWriter: trim + mix audio + H.264 at our bitrate)

Hotkey ⌃⇧S / menu ─▶ CaptureCoordinator.capture(.scrolling) ─▶ OverlayCaptureSession (area/window → ScreenRegion)
                                                               ─▶ ScrollingCaptureSession (frames + ScrollInjector + ScrollStitcher) ─▶ Capture(kind: .scrolling)
                                                               ─▶ existing tail: card, clipboard, file, editor
```

### Key technical choices

- **Recording writes with `SCRecordingOutput`** (ScreenCaptureKit, macOS 15+). Apple handles timing, drops and the file. We set the stream to 1x size, 30 fps, pointer on/off, system audio and microphone. The temp file uses Apple's default bitrate (big), and lives in the temp folder only.
- **Every export re-encodes** through `VideoExporter` (AVAssetReader → AVAssetWriter). One pipeline does trim, audio mixing (`AVAssetReaderAudioMixOutput` merges however many audio tracks the recording has) and size control (`AVVideoAverageBitRateKey`). Re-encoding 1x 30 fps video on Apple Silicon is a few seconds per minute of video. A progress bar shows it.
- **Bitrate math lives in Core** (`VideoEncoding`): bits per pixel per frame × width × height × fps, clamped to 1–20 Mbps. Quality setting picks the scale and bits per pixel.
- **Scrolling capture captures the region repeatedly** with `SCScreenshotManager` and `sourceRect`. The app posts trackpad-style scroll events (`CGEvent` scroll wheel, pixel units, continuous) at the region's centre. Needs the Accessibility permission. Without it the user scrolls by hand and presses Done.
- **Stitching is pure Core code** on frame profiles (every pixel row kept as 128 grey samples, scrollbar strip excluded; `FrameProfile`, which replaced the exact per-row hashes on 2026-10-22 because a trackpad scroll leaves the page between two pixels and no row was ever identical again). It finds how far the content moved between two frames by scoring every shift on how much the overlapping rows differ, detects sticky headers and footers, and keeps a list of slices. Assembly draws the slices into one `CGImage`.
- **A scrolling shot is a normal `Capture`** with `kind: .scrolling`. Card, clipboard, file, editor and upload work unchanged. The "Compress files" budget is multiplied by the page count so a long page is not crushed into a blurry JPEG.
- **No Quick Access card for videos.** The video window is the card: it opens on Stop and has every action.

## Core changes (`Packages/ClearShotCore`)

Reuse: `FileNamer`, `FileSaver.reserveURL`, `R2Folder.videos` (already exists), `R2Name`, `SigV4Signer`, `ScreenCoordinates`, `SelectionGeometry`, `AppSettings` pattern.

| File | Change |
|---|---|
| `Capture/CaptureKind.swift` | add `case scrolling` |
| `Capture/Capture.swift` | add `pageCount: Int = 1` (scrolling shots; drives the file budget) |
| `Capture/ScreenRegion.swift` (new) | `displayID`, `quartzRect` (global points, top-left origin), `scale`. Pixel size helper |
| `Capture/ScreenCoordinates.swift` | add `quartzRect(fromView:screenQuartzFrame:)` (inverse of the existing `viewRect(fromQuartz:...)`) |
| `Settings/AppSettings.swift` | `videoQuality: VideoQuality` (default `.smaller`), `recordsMicrophone` (true), `recordsSystemAudio` (true), `recordingShowsPointer` (true) |
| `Video/VideoEncoding.swift` (new) | `enum VideoQuality { smaller, better, retina }`; `struct Settings { width, height, fps, videoBitrate, audioBitrate }`; `settings(for pixelSize:, scale:, quality:)` (1x for smaller/better, native for retina, even dimensions, clamp bitrate); `estimatedBytes(seconds:)` |
| `Video/TrimRange.swift` (new) | `start`, `end`, `duration`; `clamped`, `minimumLength = 0.5`, `isWhole`, `movingStart(to:)`, `movingEnd(to:)` |
| `Files/FileNamer.swift` | `fileName(date:fileExtension:)`; the `ImageFormat` overload calls it |
| `Files/FileSaver.swift` | `reserveURL(fileExtension:in:date:)`; the `ImageFormat` overload calls it |
| `Cloud/R2.swift` | `R2Name.random(fileExtension:)`; the `ImageFormat` overload calls it |
| `Cloud/SigV4.swift` | `Request.payloadHash: String?` so a file can be hashed in chunks instead of loaded into memory |
| `Scrolling/FrameProfile.swift` (new; was `FrameSignature`) | `of(_ image: CGImage, columns:) -> FrameProfile`: draw into an 8-bit grey context (128 samples wide, same height); `rowDistance` and `distance` are mean absolute differences, 0…255 |
| `Scrolling/ScrollStitcher.swift` (new) | `add(_ frame: FrameProfile, expectedShift: Int?) -> Step` where `Step` is `.first`, `.appended(rows: Int)`, `.noChange` (frames differ by ≤ 1.5 on average), `.noMatch`. Keeps `slices: [Slice]` (frame index + row range), `totalHeight`, `pages`. Header/footer: leading/trailing rows that differ by ≤ 6 at the same position, found on the first scroll. Shift search over the middle band: every 4th shift on every 4th row, then every shift within 4 of the best; the shift whose overlapping rows differ least wins when that is ≤ 16 of 255; near-ties → nearest to `expectedShift`, else the smallest |
| `Scrolling/ScrollAssembler.swift` (new) | `assemble(frames: [CGImage], slices: [Slice]) -> CGImage?` with a `maxHeight` of 30 000 px |
| `Scrolling/ScrollPlanner.swift` (new) | `stepPoints(regionHeight:)` = 60 % of the height; `shouldStop(noChangeInARow:)` = ≥ 2; `shouldStop(noMatchInARow:)` = ≥ 3; `stepAfterNoMatch` halves the step |

Tests (Swift Testing, next to the existing ones): `AppSettingsTests` (new defaults persist), `FileNamerTests`, `R2Tests`, `SigV4Tests` (hash override gives the same headers), `VideoEncodingTests`, `TrimRangeTests`, `ScreenCoordinatesTests`, `FrameSignatureTests`, `ScrollStitcherTests` (synthetic page of distinct row hashes; frames at offsets; sticky header and footer; end of page gives `.noChange`; a random frame gives `.noMatch`; a few changed rows still match), `ScrollAssemblerTests` (4-pixel-wide images, check the rows).

## App changes (`ClearShot/`)

### Recording (`ClearShot/Recording/`, new folder)

| File | Role |
|---|---|
| `RecordingCoordinator.swift` | `@Observable`. State: `idle`, `choosing`, `recording(since: Date)`, `finishing`. `start(_ kind: CaptureKind)`, `stop()`, `toggle()` for the hotkey. Permission check (same as `CaptureCoordinator`). Runs `OverlayCaptureSession` for area and window. Builds the `SCContentFilter`: display + `sourceRect` (area, full screen), or `desktopIndependentWindow` (window). Excludes ClearShot's own windows from display filters so the bar never shows in the video. Mic permission just in time (`AVCaptureDevice.requestAccess(for: .audio)`); denied → record without mic and show a toast. Owns the bar, the frame and the video windows |
| `ScreenRecorder.swift` | Wraps `SCStream` + `SCRecordingOutput`. `start(filter:configuration:to url:) async throws`, `stop() async throws -> URL`. Delegate callbacks come off main: `nonisolated` delegate class like `UploadProgressDelegate` in `R2Uploader.swift`, hop to main with `Task { @MainActor in }`. Stream config: `width`/`height` from `VideoEncoding`, `minimumFrameInterval` 1/30, `showsCursor`, `capturesAudio`, `excludesCurrentProcessAudio = true`, `captureMicrophone`, `sampleRate` 48 000, `channelCount` 2, `queueDepth` 5 |
| `RecordingBarPanel.swift` + `RecordingBarView.swift` | Non-activating floating panel at the top centre of the recorded screen (same panel setup as `Toast.swift`). Pulsing red dot, `00:12`, Stop button |
| `RegionFramePanel.swift` | Click-through 2 pt border around an area (`ignoresMouseEvents = true`). Shared with scrolling capture |
| `VideoWindowController.swift` | One window per recording. Title "Recording · 0:42". Commands: Save (⌘S, to `settings.saveFolder`, Desktop by default), Save As (⇧⌘S, `NSSavePanel`, `.mpeg4Movie`), Share, Upload, Space play/pause. Close with nothing saved → "Discard this recording?" alert. After Save: toast "Saved", window closes (same as the editor). Upload and Share keep it open. Caches the last export (same range + settings) so Upload then Save does not re-encode |
| `VideoView.swift` + `TrimBar.swift` | SwiftUI: AVKit `VideoPlayer` on top; filmstrip of ~12 thumbnails (`AVAssetImageGenerator`) with two drag handles and a playhead; "Start here" / "End here" / "Reset" buttons; size label "up to ≈ 4.2 MB" from `VideoEncoding.estimatedBytes`; export progress bar with Cancel |
| `VideoExporter.swift` | `nonisolated`. `export(from:range:encoding:to:progress:) async throws`. Reader with `timeRange`; video track → BGRA → writer input with H.264 settings (`AVVideoAverageBitRateKey`, `AVVideoProfileLevelKey` High AutoLevel, `AVVideoMaxKeyFrameIntervalDurationKey` 2, `AVVideoExpectedSourceFrameRateKey` 30); all audio tracks → `AVAssetReaderAudioMixOutput` → AAC 48 kHz stereo 96 kbps. `startSession(atSourceTime: range.start)`. Writes a temp file, then replaces the target. Progress from presentation time |
| `TemporaryFiles.swift` (in `Services/`) | `recordingsFolder` under `FileManager.temporaryDirectory/ClearShot/Recordings`; `sweep(olderThan: 1 day)` at launch |

### Scrolling capture (`ClearShot/Scrolling/`, new folder)

| File | Role |
|---|---|
| `ScrollingCaptureSession.swift` | `run(region:settings:canAutoScroll:) async throws -> (CGImage, pages: Int)?`. Shows the HUD and the region frame. Auto: capture → post scroll → wait until two frames in a row are equal (poll every 80 ms, max 400 ms) → `stitcher.add`. Stops on `ScrollPlanner` rules, Esc (cancel) or Enter / Done (finish now). Manual: capture every 150 ms, feed changed frames; Enter / Done finishes. Hands frames to `ScrollAssembler` at the end |
| `ScrollInjector.swift` | `scroll(byPixels:at:)`: three `CGEvent` scroll events (phase began, changed with the delta, ended), pixel units, `scrollWheelEventIsContinuous = 1`, `location` at the region centre, posted to `.cghidEventTap` |
| `ScrollHUDPanel.swift` + view | Glass pill below (or above) the region: "Scrolling… 3 pages · Enter to finish · Esc to cancel", or "Scroll down, then press Enter" in manual mode, plus Done and Cancel buttons. Becomes key like `SelectionOverlayWindow` so Enter / Esc work |

### Edits to existing files

| File | Change |
|---|---|
| `Capture/OverlayCaptureSession.swift` | `.area` outcome also carries a `ScreenRegion` (screen's quartz frame + selection rect + scale). `.window` is unchanged; the window's `frame` is the region |
| `Capture/ScreenCapturer.swift` | `captureRegion(_:in:excludingOwnWindows:)` using `SCScreenshotConfiguration.sourceRect` (points relative to the display) and `width`/`height` in pixels, cursor off. `ownWindows(in:)` filters `content.windows` by our bundle id |
| `Capture/CaptureCoordinator.swift` | `makeCapture(.scrolling)`: overlay in area mode → region → Accessibility check → `ScrollingCaptureSession`. Budget in `finish` becomes `fileBudget × pageCount`. Alert when Accessibility is missing: "Open System Settings" / "Scroll by hand" / Cancel |
| `Services/PermissionService.swift` | `hasAccessibilityAccess` (`AXIsProcessTrusted`), `requestAccessibilityAccess()` (`AXIsProcessTrustedWithOptions` with the prompt option), `openAccessibilitySettings()`; `hasMicrophoneAccess`, `requestMicrophoneAccess() async` |
| `Services/HotkeyService.swift` | `.recordScreen` ⌃⇧R → `recording.toggle()`; `.scrollingCapture` ⌃⇧S → `coordinator.capture(.scrolling)` |
| `App/MenuBarMenu.swift` | "Scrolling Capture", divider, "Record Area" / "Record Window" / "Record Full Screen"; while recording those three become "Stop Recording" |
| `App/ClearShotApp.swift` | Menu bar label shows `record.circle.fill` in red while recording (observes `RecordingCoordinator`) |
| `App/AppDelegate.swift` | Creates `RecordingCoordinator`; sweeps temp recordings at launch |
| `Services/UploadService.swift` | `upload(fileURL:contentType:folder:with:progress:)`; the data overload stays for images |
| `Services/R2Uploader.swift` | `upload(file:contentType:key:progress:)` using `URLSession.upload(for:fromFile:)` and a chunked SHA-256 of the file passed as `payloadHash` |
| `Settings/SettingsView.swift` | General: new "Recording" section (Quality picker Smaller / Better / Retina with a one-line footer on file size; toggles for microphone, system audio, pointer). Shortcuts: two new recorders and a footer "Press the record shortcut again to stop." |
| `project.yml` | `NSMicrophoneUsageDescription: "ClearShot records your voice when a recording has the microphone on."` under `info.properties` (Info.plist is generated) |
| `README.md` | Features, shortcuts, the Accessibility and Microphone permissions, file-size note |

## Tasks (in order, commit after each)

1. **Core: settings, names, video math.** `AppSettings` fields, `FileNamer` / `FileSaver` / `R2Name` extension overloads, `SigV4Signer.Request.payloadHash`, `VideoEncoding`, `TrimRange`, `ScreenRegion`, `ScreenCoordinates.quartzRect(fromView:)`, `CaptureKind.scrolling`, `Capture.pageCount`. Tests for each. `make core-test` green.
2. **Recording to a temp file.** `ScreenRecorder`, `RecordingCoordinator` (all three modes), bar panel, region frame, menu items, hotkey, menu bar icon, mic permission, `TemporaryFiles`. Stop opens the temp file in QuickTime for now. Early check in this task: record 10 s with mic + system audio and print the audio track count of the file (`AVAsset.loadTracks(withMediaType: .audio)`). On macOS 27 the recording output mixes them into one track by default; on macOS 26 it may write two. The exporter in Task 3 handles both, so this is only to know what we have.
3. **Video window and export.** `VideoExporter`, `VideoWindowController`, `VideoView`, `TrimBar`, Save and Save As, discard confirm, export cache, progress and cancel. Replace the QuickTime stub from Task 2.
4. **Share and Upload for videos.** File upload path in `R2Uploader` and `UploadService`, `videos/` folder, link copied, progress ring, Share via `ShareService.share`.
5. **Core: stitching.** `FrameSignature`, `ScrollStitcher`, `ScrollAssembler`, `ScrollPlanner` with the tests listed above.
6. **Scrolling capture in the app.** Overlay region outcome, `captureRegion`, `ScrollInjector`, Accessibility permission flow, `ScrollingCaptureSession`, HUD, `CaptureCoordinator.scrolling`, page-aware budget, hotkey, menu, settings.
7. **Docs.** README, `docs/superpowers/specs/2026-10-14-recording-and-scrolling-design.md` (this design), plan copy in `docs/superpowers/plans/`.

Each task ends with `make check` (core tests + app build) before the commit.

## Verification

Automated: `make check` after every task. New Core suites must pass alongside the existing 170 tests.

Manual, after Task 4:

- Record Area, Window, Full screen for ~60 s of normal UI work with the mic on. Check in Finder: Smaller ≤ 15 MB, Better ≤ 30 MB. Open in QuickTime: one audio track, voice and system sound both audible, pointer visible.
- Trim 5 s off each end. Saved file starts and ends where the handles were (within one frame). Size label was within ~30 % of the real size.
- Save lands on the Desktop as `ClearShot 2026-10-14 at 13.50.12.mp4`. Save As picks a folder. Closing an unsaved recording asks first.
- Upload: link copied, plays in Safari and Chrome. Upload then Save does not re-encode (watch the log).
- Mic denied in System Settings: recording still works, toast says the mic is off.
- Hotkey ⌃⇧R twice: starts, then stops. Menu bar icon turns red while recording. The bar is not in the video.
- Temp folder is empty after Save and after Discard.

Manual, after Task 6:

- Safari on a long page: ⌃⇧S, drag the content area. Auto-scrolls, stops at the bottom, card shows the tall image, editor opens it, file saves (PNG, size under budget × pages).
- A page with a sticky header (GitHub, Notion): header appears once at the top, not repeated.
- Accessibility off: alert offers "Scroll by hand"; scrolling by trackpad and pressing Enter gives the same result.
- Esc mid-way cancels; Enter mid-way keeps what is there.
- Window mode (Space) uses the window's frame as the region.

## Risks and open points

- **Microphone through `SCRecordingOutput` on macOS 26.** Task 2 checks the track count. Worst case (no mic track at all) → fall back to our own `AVAssetWriter` fed by `SCStreamOutput` sample buffers. Same exporter still applies.
- **Synthetic scroll events.** Need Accessibility; some Electron apps ignore continuous scroll deltas. Manual mode covers it. Ad-hoc signed dev builds can lose Accessibility trust after a rebuild (dev only).
- **Stitching edge cases.** Lazy-loading pages, animations, repeating rows. `.noMatch` skips the frame and halves the step; three in a row stops with what we have. The HUD says so.
- **Export time** for long recordings (about 5–10 s per minute of video). Progress bar and Cancel are in the design.
- **Window resized while recording.** ScreenCaptureKit scales to fit the configured size. Accept for v1.

## Out of scope (later)

GIF export, countdown before recording, pause/resume, HEVC, webcam overlay, click highlights (`showMouseClicks` is one line if wanted), a Quick Access card for videos, annotations on video.


## What changed while building

- **AVKit's SwiftUI `VideoPlayer` aborts at launch** on macOS 27.0 (a Swift runtime failure inside `_AVKit_SwiftUI`). The video window uses the AppKit `AVPlayerView` through an `NSViewRepresentable` instead.
- **Excluding the app from a display capture did not keep the bar out of the video.** The bar and the frame are now created (invisible) before the content snapshot and the filter excludes them by window; they get their content and fade in once the stream runs.
- **ScreenCaptureKit's recording output on macOS 27 writes one audio track** (system sound and the microphone mixed by default). The exporter still mixes whatever tracks it finds, so macOS 26 works too.
- **Microphone permission** is asked just before the first recording with the microphone on; refused, the recording goes on without it and a toast says so.
- The stitcher's minimum overlap is a tenth of the frame (not a fixed 40 rows) and sticky header and footer sizes are only kept once a scroll really matched. There is no cap on their size.
- No Quick Access card for videos: the video window is the card.
