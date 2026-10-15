# ClearShot: scrolling capture, matched to Record

> The approved design, 2026-10-14. Builds on `2026-10-14-recording-toolbar-and-cards-design.md`. See the end for what changed while building.

## Context

Scrolling capture does not work well:

- **Auto stops at once.** Every try ended after 1 frame in about 1.5 s: the page never moved, so ClearShot decided "end of page" and saved the one picture as a normal screenshot. To Austin it looked like it captured at random points. Why the page did not move is not known yet.
- **The question box could not be clicked.** The area picker's overlay stayed on top of it (fixed already: the picker returns only once its overlay is gone).
- **It does not feel like Record.** No toolbar, no Change Area, no window or full screen choice, and a modal question instead of a switch.

Decisions made with Austin:

| Question | Answer |
|---|---|
| What comes out | One long screenshot (not a video) |
| Targets | Three menu items, like Record: Scrolling Capture Area / Window / Full Screen. ⌃⇧S starts Area |
| Done | Card, then Edit to crop, like screenshots and recordings |
| Mode at start | Always By hand |
| Auto at the end of the page | Stop and wait for Done |
| Bar place | Bottom centre, like the recording bar |
| Extras | Live preview |

## The flow

1. Scrolling Capture Area, Window or Full Screen (menu), or ⌃⇧S for Area (Space switches to Window).
2. Pick the area or window. Full Screen skips this. A window becomes its spot on screen and its app comes to the front (same as recording).
3. A thin frame shows the area. The toolbar fades in at the bottom centre:
   `✕ · [✋ By hand | ↓ Auto] · Change Area · ▶ Start`
   - It always starts on By hand.
   - Auto without the Accessibility permission: the system prompt and System Settings open, a toast says "Allow ClearShot in Accessibility, then pick Auto again", and the switch stays on By hand.
   - Change Area (Change Window) picks again; Esc there goes back to the toolbar. Full Screen has no Change button.
   - Start is in the accent colour (red means video). Enter = Start, Esc = cancel.
4. Start: the toolbar becomes the bar in the same spot: `↕ 3 pages · ✓ Done · ✕`. Enter = Done, Esc = cancel. The live preview appears beside the area.
   - By hand: a picture every 150 ms; each new part is added to the tall image.
   - Auto: ClearShot scrolls and adds. At the end of the page (or when it loses track) it stops scrolling, the bar says "End of page", and it waits. Scrolling by hand still adds.
5. Done (bar, Enter, menu, or ⌃⇧S): shutter sound and flash, then the card, the clipboard and the file, exactly like a screenshot. Edit opens the editor, which has Crop.

The toolbar, the bar, the frame and the preview are never in the image.

## Live preview

A glass strip, about 120 pt wide, to the right of the area (left when there is no room, inside the right edge for a full screen). As tall as the area, within the visible screen. It shows the tall image scaled to its width, with the newest part at the bottom. Clicks and scrolls go through it.

## Key technical choices

- **A `ScrollingCoordinator`**, like `RecordingCoordinator`: idle → choosing → ready → capturing. It hands the finished `Capture` to `CaptureCoordinator`'s shared tail (card, clipboard, file). The modal question in `CaptureCoordinator` goes.
- **Shared parts with recording:**
  - `RegionPicker`: area / window / full screen → `ScreenRegion` (window spot, app to the front).
  - `ToolbarPanel`: the key-capable bottom-centre panel (Enter / Esc), and the toolbar's parts (close button, separator, option chip, action button).
- **`ScrollingCaptureSession`** only takes and stitches frames now. Its state (pages, end reached, preview slices) is observable; `finish()` and `cancel()` end it. The panels belong to the coordinator and exist before the content snapshot, so the shots leave them out.
- **Auto fix, evidence first:** log whether ClearShot may post events (`CGPreflightPostEventAccess`) and every scroll step (added N rows / no change / no match). Then fix the cause the log shows.
- **Preview slices** are crops of the kept frames (`CGImage.cropping`, no copy), one per stitcher slice.

## Core changes

| File | Change |
|---|---|
| `Scrolling/SidePanelLayout.swift` (new) | Where the preview goes: right of the area, else left, else inside the screen's right edge; height within the visible screen |

## App changes

| File | Change |
|---|---|
| `Capture/RegionPicker.swift` (new) | Pick a region for a kind; window spot |
| `Capture/ToolbarPanel.swift` (new) | The panel and the shared toolbar parts |
| `Capture/CaptureCoordinator.swift` | Drop `.scrolling` and the question; `deliver(_:)` is the shared tail |
| `Scrolling/ScrollingCoordinator.swift` (new) | The flow above |
| `Scrolling/ScrollingCaptureSession.swift` | Frames only; observable state; finish / cancel; step logging |
| `Scrolling/ScrollToolbarView.swift` (new) | The toolbar and the bar |
| `Scrolling/ScrollPreviewPanel.swift` (new) | The live preview |
| `Scrolling/ScrollHUDPanel.swift` | Removed (replaced by the toolbar and bar) |
| `Recording/*` | Use `RegionPicker` and `ToolbarPanel` |
| `App/MenuBarMenu.swift`, `App/AppDelegate.swift`, `Services/HotkeyService.swift` | Three menu items; Done / Cancel while capturing; ⌃⇧S toggles |
| `Settings/SettingsView.swift`, `README.md` | Text for the new flow |

## Tasks (in order)

1. Core: `SidePanelLayout`, tests first.
2. Shared parts: `RegionPicker`, `ToolbarPanel`; recording uses them (no change in behaviour).
3. Scrolling flow: coordinator, toolbar, bar, session rework, menu, hotkey, Done → card.
4. Live preview.
5. Auto: logging, live test on a long page, fix.
6. Docs.

Each task ends with `make check`.

## Verification

- ⌃⇧S on a long page, By hand: scroll down, the pages count and preview grow, Enter: card with the tall image.
- Auto on Safari: it scrolls to the end, says "End of page", waits; Done gives the card.
- Auto without Accessibility: prompt and Settings open; the switch stays on By hand.
- Window and Full Screen work; Change Area and Esc go back to the toolbar.
- The bar, toolbar, frame and preview are not in the image.

## Out of scope

A video of the scroll, scroll speed, a countdown, scrolling up or sideways.

## What changed while building

- The toolbar panel and the region picker moved to `Capture/ToolbarPanel.swift` and `Capture/RegionPicker.swift`; recording uses them too (no change in behaviour).
- `ScrollHUDPanel` is gone; the bar is the same `ToolbarPanel` as the toolbar, with new content.
- **Why every capture kept one picture:** frames were matched by whole rows. In a window or full screen, a sidebar or toolbar that stays put sits in every row, so after a scroll no whole row matched (Auto's step log showed the page moving and "no overlap" every time; By hand failed the same way). Fix: `ScrollBand` finds the columns that moved between the first picture and the first one that differs (columns where at least 20 % of rows changed, so a caret or clock does not count); rows are hashed (`FrameSignature.rows(of:columns:)`) and the page assembled (`ScrollAssembler.assemble(…columns:)`) from that band only, minus the scrollbar strip at its right. Austin chose this: the result is only the part that scrolls.
- By hand looks every 50 ms (was 150), so a quick trackpad flick still overlaps; when it does not, the bar says "Too fast · scroll back up a little", and scrolling back lets it carry on.
