# ClearShot: record toolbar, pause, click pulse and recording cards

> The approved design, 2026-10-14. Builds on `2026-10-14-recording-and-scrolling-design.md`. See the end for what changed while building.

## Context

Recording works, but it does not feel like the rest of ClearShot:

- Picking an area starts the recording at once, with the screenshot shutter sound.
- There is no way to check the options, change the area or pause.
- Stop opens a video window and nothing is saved until Save. Screenshots are saved at once and get a card.

Goal: recordings follow the same standard as screenshots. Pick → get ready → record → card → Edit.

Decisions made with Austin:

| Question | Answer |
|---|---|
| Save on Stop | Yes, right away to the save folder, like a screenshot |
| Where recording cards go | Same row as screenshot cards (bottom-left), newest on the left |
| Toolbar | Bottom centre, one bar: options + Record before, time + Pause + Stop during |
| Extras | Click pulse, 3-2-1 countdown, hover preview on the card. No keys on screen |
| Click pulse in Window mode | Window mode records the window's spot on screen, so the pulse shows |
| Mic button | On/off plus a list of microphones, remembered |
| Countdown | Always on (no switch) |
| Video editor | Buttons on top like the screenshot editor: Upload, Share, Copy, Save ▾. Trim is the filmstrip with two handles |
| Sounds | macOS's own record sounds: one on start (after the countdown), one on Stop. No shutter sound |
| Clipboard on Stop | Follows the "Copy to the clipboard" setting, like screenshots |
| Pause | Split files: each Pause ends a piece, Resume starts a new one, Stop joins them |

## The flow

1. Record Area, Window or Full Screen (menu, or ⌃⇧R for area).
2. Pick the area or window. No sound. Full Screen skips this.
   - Window mode turns the window into its spot on screen (a region), and brings its app to the front.
3. A thin frame shows what will be recorded. The toolbar fades in at the bottom centre of that screen:
   `✕ · Mic ▾ · Sound · Pointer · Clicks · Quality ▾ · Change Area · ● Record`
   - Every switch writes straight to `AppSettings`, so it is remembered and matches Settings → Recording.
   - Mic ▾ lists the microphones ("Default" first). Turning Mic on asks for the permission if needed.
   - Change Area (Change Window in window mode) hides the toolbar and opens the picker again. Esc there goes back to the toolbar with the old area. Full Screen has no Change button.
   - Enter = Record, Esc = cancel (the toolbar takes keys without activating the app, like the overlay).
4. Record → 3-2-1 in a glass circle in the middle of the area. The toolbar's Record button shows the count and Esc still cancels.
5. Start sound (`begin_record.caf`). Recording starts. The toolbar goes (keys return to the app you were in) and the recording bar fades in at the same spot: `● 0:12 · Pause · Stop`.
6. Pause → the piece ends, the time stops, the bar shows `❚❚ 0:12 · Resume · Stop`, the menu bar icon shows a pause sign. Resume → a new piece starts.
7. Stop (bar, menu, or ⌃⇧R) → stop sound (`end_record.caf`).
8. The card shows at once with the first frame and a "Saving" ring. The pieces are joined and compressed into the save folder as `ClearShot 2026-10-14 at 22.30.05.mp4`. Then the card comes alive, and the file goes to the clipboard if that setting is on.

The toolbar, the recording bar, the frame and the countdown are never in the video. The click pulse is.

Why the "Saving" ring: Apple's recorder writes a big file at its own bitrate. We re-encode it at our bitrate to keep it small (about 5–10 s per minute of video). Before, this ran on Save; now it runs on Stop.

## The card (recordings)

Same card, same row, same auto-close, same drag-out as screenshots. Differences:

- Picture: the first frame. On hover (once saved), the video plays muted on a loop.
- Top right: `▶ 0:42` (the length) in place of the pixel size.
- While saving: a small ring with the percent over the picture; the action icons are greyed out.
- Copy puts the file on the clipboard (pastes as a file in Slack, Mail, Finder).
- Share shares the file. Upload sends it to `videos/` and copies the link. Reveal, Trash: same as screenshots.
- Edit opens the video editor.

## The video editor

```text
┌──────────────────────────────────────────────────────────────┐
│ 0:42                           [Upload] [Share] [Copy] [Save ▾] │  48 pt bar, like EditorToolbar
├──────────────────────────────────────────────────────────────┤
│                         player                               │
├──────────────────────────────────────────────────────────────┤
│ ┃▒▒▒▒▒▒▒▒▒▒▒▒ filmstrip ▒▒▒▒▒▒▒▒▒▒▒▒┃   0:08 kept · ≈ 2 MB  ↺   │
└──────────────────────────────────────────────────────────────┘
```

- Window title: the file name (like the screenshot editor).
- Trim: drag the two handles; click the strip to jump. ↺ shows only after a trim. While exporting, the bottom right shows a progress bar and Cancel.
- Save (⌘S): no trim → just close. Trimmed → export, replace the file, close. The card closes too, like the screenshot editor.
- Save As (⇧⌘S): writes a new file; the original stays. Closes.
- Copy (⌘C): the trimmed cut (or the file) to the clipboard. Closes.
- Upload: the trimmed cut (or the file). Copies the link. Closes.
- Share: the trimmed cut (or the file). Stays open.
- Closing without saving: no prompt (the file is saved). The trim is kept while the card is open, using `EditorLifetime` like the screenshot editor.
- Trash on the card closes the editor.

Removed: the "Discard this recording?" prompt, Start Here / End Here, the video window opening on Stop, deleting the source on close.

## Key technical choices

- **Pieces via `SCRecordingOutput`.** The stream starts when Record is pressed (so the countdown hides the start-up time). Each piece adds a recording output to the running stream; Pause removes it. Not certain this works mid-stream on macOS 27; it is tested first. Fallback: one stream per piece (Resume then takes about 0.3 s).
- **Join and compress in one pass.** An `AVMutableComposition` of the pieces goes through the existing `VideoExporter` (it now takes an `AVAsset`, not a URL). One piece → the file itself.
- **Window mode is a region.** The window's frame becomes a `ScreenRegion` on its display, recorded like an area. It shows the click pulse and what is on top of the window. If the window moves, the video does not follow.
- **Click pulse** is a click-through panel over the recorded screen, left out of the exclusion list so it is in the video. A global mouse monitor (`NSEvent.addGlobalMonitorForEvents`, no permission for mouse events) adds a ring in the accent colour per left or right click. Clicks on ClearShot's own bar do not pulse.
- **The toolbar** is a non-activating panel that can become key (Enter / Esc). The recording bar is a separate panel that never takes keys, reserved before the capture filter is made (as today).
- **A recording is a `Capture`** with a `video` field (length + encoding). `image` is the first frame. Cards, Reveal, Trash and drag-out work unchanged; Edit, Copy, Share and Upload branch on `video`.
- **`VideoEditorStore`** (like `EditorSessionStore`) keeps one editor per card.

## Core changes (`Packages/ClearShotCore`)

| File | Change |
|---|---|
| `Video/RecordingClock.swift` (new) | Time recorded so far with pauses: `start`, `pause`, `resume`, `elapsed(at:)`, `isPaused` |
| `Video/VideoTime.swift` (new) | `clock(_:decimals:)` and `length(_:)`, moved from `VideoView` so the card and editor share them |
| `Capture/Capture.swift` | `video: Capture.Video?` with `duration` and `encoding`; `isVideo` |
| `Settings/AppSettings.swift` | `recordingShowsClicks` (default on), `microphoneID: String?` (nil = the system default) |

Tests for each, alongside the existing ones.

## App changes (`ClearShot/`)

| File | Change |
|---|---|
| `Recording/RecordingCoordinator.swift` | States: idle, choosing, ready, countdown, recording, paused, finishing. `record()`, `pause()`, `resume()`, `stop()`, `cancel()`, `changeTarget()`. Hands the result to the card |
| `Recording/ScreenRecorder.swift` | `startStream`, `beginPiece(to:)`, `endPiece()`, `stop() -> [URL]`; a delegate per piece |
| `Recording/RecordingToolbarPanel.swift` (new) | The options bar (key-capable panel + SwiftUI view) |
| `Recording/RecordingBarPanel.swift` | Bottom centre; Pause / Resume; time from `RecordingClock` |
| `Recording/CountdownPanel.swift` (new) | 3-2-1 in a glass circle |
| `Recording/ClickPulsePanel.swift` (new) | Rings where you click |
| `Recording/RecordingFinisher.swift` (new) | Join + compress + save + poster frame |
| `Recording/VideoExporter.swift` | Takes an `AVAsset` |
| `Recording/VideoWindowController.swift`, `VideoView.swift` | The editor above; opens a saved file; never deletes it |
| `Recording/VideoEditorStore.swift` (new) | One editor per card, kept while the card is open and the trim is unsaved |
| `Overlay/QuickAccessView.swift`, `QuickAccessController.swift` | Video badge, saving ring, hover preview, file Copy / Share / Upload |
| `Services/SoundPlayer.swift` | `playRecordStart()`, `playRecordStop()` |
| `Services/ClipboardService.swift` | `copy(fileURL:)` |
| `App/AppDelegate.swift` | Edit / Trash / dismiss route videos to `VideoEditorStore` |
| `App/MenuBarMenu.swift`, `App/ClearShotApp.swift` | Pause / Resume / Cancel items; pause icon |
| `Settings/SettingsView.swift` | "Play sounds"; Microphone picker; "Show clicks"; shortcut footer |
| `README.md` | The new flow |

## Tasks (in order)

1. **Core.** `RecordingClock`, `VideoTime`, `Capture.video`, the two settings. Tests first. `make core-test` green.
2. **Pieces.** `ScreenRecorder` with pieces. Live check: record, pause, resume, stop; two files, both play.
3. **Toolbar and countdown.** The new flow up to "recording", Change Area, mic list, sounds, bar with Pause / Resume, menu, icon.
4. **Click pulse.**
5. **Stop → card.** Join + compress + save, card with saving ring, badge, hover preview, file Copy / Share / Upload, clipboard setting.
6. **Video editor.** New layout, Save replaces, Copy, store, AppDelegate wiring.
7. **Settings and docs.**

Each task ends with `make check` (core tests + app build).

## Verification

Automated: `make check`.

By hand:

- Record Area: no shutter sound. Toolbar at the bottom centre. Change Area, then Esc: back to the toolbar, old area. Enter: 3-2-1, start sound, bar.
- Pause 5 s, Resume, Stop. The file has no gap and no paused part. The time on the bar matched.
- Clicks during recording show rings in the video (area, full screen, window).
- Window mode: the window's app comes to the front; the video is the window's spot.
- Card: first frame, `▶ length`, saving ring, then hover plays. Copy → paste into Finder gives the mp4. Upload → link works.
- Edit → trim → Save: the file is shorter, the card and editor close. Edit → close without saving → Edit again: the trim is still there.
- Mic on with AirPods picked: voice is in the video.
- The toolbar, bar, frame and countdown are not in any video.

## Risks and open points

- **Adding and removing a recording output on a running stream** is not proven on macOS 27. Task 2 checks it first; the fallback is a stream per piece.
- **Global mouse monitor** may need a permission on macOS 27. If it does, the Clicks switch explains it.
- **Re-encode on Stop** takes 5–10 s per minute of video. The ring shows it. A long recording's card waits longer.
- **Two encodes after a trim** (Stop, then Save). At these bitrates the loss is not visible.

## Out of scope

Keys on screen, a pause hotkey, a mode switcher in the toolbar, following a moving window, GIF export, webcam.

## What changed while building

- **Adding and removing a recording output on a running stream works** on macOS 27 (checked live: Pause and Resume gave two pieces, both finished, joined into one file). No fallback was needed.
- The stream gets a do-nothing screen output, so it has somewhere to send frames between pieces.
- `NSObject` already has `copy()`, so the editor's Copy is `copyToClipboard()`, like the screenshot editor.
- The toolbar's switches use the accent colour; with the Graphite accent "on" and "off" looked alike, so "on" now also has a brighter label and an outline.
- If compressing fails for a one-piece recording, the raw piece is saved instead (big, but nothing is lost).
