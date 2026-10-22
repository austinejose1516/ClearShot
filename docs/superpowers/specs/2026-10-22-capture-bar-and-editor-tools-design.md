# ClearShot: one capture bar, sticky editor tools, new defaults

> Draft for Austin's approval, 2026-10-22. Builds on the 2026-10-14 specs (recording toolbar, scrolling capture toolbar).

## Context

- Austin: the same three choices (Area, Window, Full Screen) under Screenshot, Scrolling Capture and Record is not nice. He picked **Option 1**: one on-screen bar, like macOS ⇧⌘5 and CleanShot X, for the menu. The keyboard stays as it is: ⇧⌘3 / ⇧⌘4 / ⇧⌘5 work as on macOS, and every action keeps its own shortcut that the user can set.
- Editor asks: default width 10 px for every shape; default text size 24 with more sizes; speech bubble text 24 too; a tool stays on after use, and over an existing shape the pointer takes over.
- Not in this change: the toolbar's look (colours, corners, shadow), which is a separate design.

## Part 1: the capture bar

### What the user sees

1. Pick **Screenshot**, **Scrolling Capture** or **Record** in the menu, or press the bar's shortcut (⇧⌘5 when the macOS keys are on). Every screen freezes and dims, as today. On the screen under the mouse a glass bar fades in at the bottom centre:

   ```text
   ✕ │ 📷 Screenshot · ↕ Scrolling · ⏺ Record │ ▭ Area · ▢ Window · 🖥 Full screen │ Drag an area
   ```

   - Left group: **what** to make; the menu item picks it. Right group: **how** to pick. Both are remembered for the next time.
   - The text at the right says what to do now: "Drag an area", "Click a window", "Click a screen".
2. Picking:
   - **Area**: drag a box, with the size label, as today.
   - **Window**: hover highlights a window, click picks it, as today.
   - **Full screen**: the dim lifts from the screen under the mouse; click anywhere on it to pick that screen. Moving to another screen lights that one instead.
   - **Space** still switches Area ↔ Window; the bar follows.
3. After the pick:
   - **Screenshot**: taken at once (flash, sound, card), as today. Full screen uses the frozen picture of that screen, so it is instant.
   - **Scrolling** or **Record**: the overlay closes and the known toolbar appears (By hand / Auto, or Mic / Sound / Pointer / Clicks / quality) with Change Area / Change Window and Start / Record. Nothing changes there.
4. **Esc** or **✕** cancels. Clicking a bar button never captures by itself.
5. The bar is never in the picture (the overlay closes before anything is captured, as today).

### Shortcuts

Nothing is taken away. Every shortcut goes straight to its pick, no bar, exactly as today, and every one can be set in Settings:

| Key | Does (as today) |
|---|---|
| ⌃⇧A / ⌃⇧W / ⌃⇧F | Screenshot of an area (Space switches to a window) / a window / the full screen |
| ⌃⇧S / ⌃⌥⇧S / ⌃⇧⌘S | Scrolling capture of an area / a window / the full screen; again to Start, again for Done |
| ⌃⇧R / ⌃⌥⇧R / ⌃⇧⌘R | Record an area / a window / the full screen; again to Record, again to Stop |
| ⌃⇧P | Pause / resume |

One new shortcut, **Capture bar**: opens the bar with the remembered what and how. No key by default; **Use the macOS shortcuts** sets ⇧⌘3 = full-screen screenshot, ⇧⌘4 = area screenshot and ⇧⌘5 = the bar, which is what those keys do on macOS. (Today ⇧⌘5 was set to Window.)

### The menu

Three plain items instead of three submenus: **Screenshot**, **Scrolling Capture**, **Record**. Each opens the bar on that mode, where the user picks Area, Window or Full screen. The running controls (Pause, Stop, Done, Cancel) stay first while a recording or a scrolling capture runs. Scrolling Capture and Record are greyed out while one of them runs, as today.

### Settings → Shortcuts

As today, plus a **Capture bar** recorder in a new first section. The macOS-keys footer now says ⇧⌘5 opens the bar.

### Code

Core (`ClearShotCore`, tested):

| Piece | What |
|---|---|
| `Capture/CaptureAction.swift` (new) | `enum CaptureAction: screenshot, scrolling, recording` with `title` and `symbol` |
| `Capture/PickMode.swift` (new) | `enum PickMode: area, window, fullScreen` with `title`, `symbol`, `hint` and `kind: CaptureKind` (what a finished capture is called). `CaptureKind` stays as it is, for files, cards and logs |
| `Settings/AppSettings.swift` | `lastCaptureAction`, `lastPickMode`, saved in UserDefaults |
| `Capture/CaptureBarModel.swift` (new) | `@Observable`: `action`, `pickMode`, `hint`; `remember(in: AppSettings)` |

App:

| Piece | What |
|---|---|
| `Capture/CaptureBarView.swift` (new) | The bar: `ToolbarCapsule` with `ToolbarCloseButton`, two groups of `OptionChip`, the hint |
| `Capture/OverlayState.swift` | `mode` becomes `pickMode: PickMode`; holds the `CaptureBarModel?` |
| `Capture/CaptureOverlayView.swift` | Shows the area view, the window view, or the new full-screen view (no dim, click picks); the bar at the bottom on the screen under the mouse |
| `Capture/OverlayCaptureSession.swift` | `run(bar: CaptureBarModel?, settings:)`. `Outcome` gains `.fullScreen(frozen: CGImage, region: ScreenRegion)`. With `bar == nil` it is today's picker, used by Change Area / Change Window |
| `Capture/CaptureLauncher.swift` (new) | `open(_ action: CaptureAction?)`: runs the overlay with the bar (on `action`, or the remembered one for the bar's shortcut), then hands the outcome on: screenshot → `CaptureCoordinator`, scrolling → `ScrollingCoordinator.start(with:)`, recording → `RecordingCoordinator.start(with:)`. Does nothing while a recording or a scrolling capture is under way |
| `Recording/RecordingCoordinator.swift`, `Scrolling/ScrollingCoordinator.swift` | Gain `start(with target: RegionPicker.Target, kind: CaptureKind)` for the bar's result; `start(kind)` and `toggle(kind)` stay for the shortcuts. Change Area keeps `RegionPicker.pick` |
| `Capture/CaptureCoordinator.swift` | `capture(kind)` stays for the shortcuts; a new `deliver(outcome:)` takes the bar's result |
| `Services/HotkeyService.swift` | One new name, `captureBar`; the others unchanged |
| `App/MenuBarMenu.swift` | Three items, each opening the bar |
| `Settings/SettingsView.swift` | The Capture bar recorder; ⇧⌘5 → the bar in `useSystemShortcuts()` |
| `README.md` | Capture section and the shortcuts table |

## Part 2: editor

### Defaults

- **Width**: default 10 px (was 4) for line, arrow, pen, rectangle, ellipse and the speech bubble border. The slider stays 1 to 40. The highlighter keeps its own 32 (it is a marker, not a line).
- **Text size**: default 24 (was 32). Sizes: 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 96, 128. The speech bubble text defaults to 24 too.

### Sticky tools

- Every drawing tool stays on after use: Line, Arrow, Pen, Highlighter, Rectangle, Ellipse, Text, Speech bubble, Step, Blur. (Today only Pen, Highlighter, Step and Blur stay.)
- The shape just drawn stays selected, so a toolbar change (colour, width, Both ends, size…) applies to it and becomes the default for the next one, as today.
- Over an existing shape the cursor becomes the **arrow** (today: an open hand). Press and drag moves it; a dot resizes it; a selected text is edited on click. All as today, only the cursor changes. Off the shape, the tool's crosshair is back. The toolbar keeps showing the tool as selected the whole time.
- Back to **Select**: Esc, or click Select in the toolbar. A plain click on empty space clears the selection and keeps the tool (today it went back to Select).
- Crop is unchanged: Crop or Enter applies it, then Select.
- The hints and the README line "Shape and text tools hand back to the pointer after one use" change to match.

### Code

| Piece | What |
|---|---|
| `Editor/Annotation.swift` | `Style.defaultWidth` 4 → 10 |
| `Editor/Style.swift` | `fontSize` 32 → 24; `fontSizes` list above |
| `Editor/Figures.swift` | `Bubble.init` default `fontSize` 32 → 24 |
| `Editor/EditorTool.swift` | `staysActive` true for every tool but Crop's special case; hints |
| `Editor/EditorSession.swift` | A plain click with a drawing tool keeps the tool; `cursor(at:)` answers `.move` as today, and the App maps `.move` to the arrow |
| `ClearShot/Editor/EditorCanvasView.swift` | `.move` → `NSCursor.arrow`; `.closedHand` while dragging stays |
| Tests | `EditorToolTests` (every tool stays on), `EditorSessionTests` (tool stays after a drag and after a plain click; the new shape is selected), `StyleTests` (defaults), `FigureTests` (bubble default) |

## Calls made by Claude (say if you want them different)

1. The bar shows both groups (what and how), so ⇧⌘5 does everything the macOS bar does. From the menu, the what is already picked.
2. The bar's own shortcut has no key until the user sets one or presses Use the macOS shortcuts.
3. The highlighter keeps its own width (32).
4. A plain click on empty space clears the selection and keeps the tool; Esc or the Select button goes back to Select.
5. Over a shape the cursor is the arrow for every tool, including Select (today an open hand).
6. The bar shows on one screen only: the one under the mouse when it opens.

## Tests to write first

- Core: `CaptureBarModel` (hint per pick mode, `kind` per pick mode, remembered values round-trip through `AppSettings`), `PickMode.kind`, `EditorTool.staysActive`, `StyleValues` and `Bubble` defaults, `EditorSession` sticky behaviour.
- App has no unit tests; the build and a live check cover the bar.

## Live check for Austin

1. Menu → Screenshot: the bar on Screenshot; drag an area; the card appears. Space switches to Window; the bar follows.
2. Menu → Record: on the bar pick Full screen; click the screen; the record toolbar appears for that screen.
3. Menu → Scrolling Capture: pick a window; the scroll toolbar appears.
4. ⌃⇧A, ⌃⇧W, ⌃⇧F, ⌃⇧R, ⌃⇧S: straight to the pick, no bar, as before. After Use the macOS shortcuts, ⇧⌘5 opens the bar.
5. Editor: draw three rectangles in a row without re-picking the tool; hover one, see the arrow, move it; Esc goes back to Select. New text is 24; new lines are 10 px wide.
