# ClearShot: editors end with Done, the card acts

> The approved design, 2026-10-14 (Save became Done the same evening). Applies to the screenshot editor (screenshots and scrolling shots) and the video editor.

## Context

Saving in an editor closed it and the card, so there was no way to edit, save, then upload. Upload, Share and Copy also lived in two places (editor and card).

Decisions made with Austin:

| Question | Answer |
|---|---|
| After Done | The editor goes back into the card; the card shows the result and saves it into its own file |
| Editor buttons | Done only (⌘S). No Save As. Copy, Share and Upload are on the card only. Same for every capture kind |
| Edit again | The drawings are still editable while the card is open (a video opens the trimmed file) |
| Feedback | The editor shrinks into its card; the card bounces and says "Saved" |
| Edit | The card grows into the editor; it is hidden while editing (the other cards close the gap) |
| Close without saving | The editor also shrinks back into the card |

## Design

- `EditorCommand` loses `.copy`, `.upload` and `.saveAs`; `.save` is `.done` (⌘S). ⌘C and ⇧⌘S are no longer editor keys.
- The screenshot editor writes no file. Done renders the result and hands it to the card (nil when nothing was edited: the card and file stay). `QuickAccessController.editorDone` shows it at once and rewrites the card's file in the background with `FileSaver.overwrite` (same format and budget; a budget JPEG renames the file). If the first save is still running, the edit waits for it. This removes the Save As prompt that appeared when Edit was pressed before the file existed (a scrolling shot took 9 s to encode).
- The video editor's Done writes a trim into the recording's own file (it was always saved before Edit was possible).
- `Capture.edited(image:)` and `Capture.saved(videoDuration:poster:at:)` keep the card's identity and swap the picture (and length). An edited picture drops `windowImage`, so it is the new starting point.
- `CardPresentation` holds the card's picture and length, so the card redraws; `savedCount` drives the bounce and the "Saved" pill. An old upload link is cleared.
- `CardTransition` owns the move both ways, as one picture flying between the card's thumbnail and the spot where the editor shows it (`pictureFrameOnScreen`: the canvas centred under the toolbar at the current zoom; for a video, the frame fitted in the player). The picture is a Core Animation layer on a see-through panel, moved by a spring (no bounce) with a path-drawn shadow, so it runs on the GPU. `open`: the card leaves the row (`sendAway`), the editor is shown invisible and activated at once (while the Edit click counts, or Stage Manager keeps it in the strip), the picture flies to the canvas, the editor fades in around it. `close` (Done, or the close button via `windowShouldClose`): the editor fades out as its picture flies into the card's thumbnail spot (`makeRoom`), then the card takes the result and shows (`bringBack`). No card: the editor fades in and out. However a window closes, the card comes back.
- A card that is away takes no place in the row and never auto-closes.
- The screenshot editor's session stays while the card is open (`EditorLifetime`: it has drawings), so Edit brings them back.
- The video editor is freed after Done with a trim; Edit opens the trimmed file afresh.

## Verification

- Area, window, full screen and scrolling shots: Edit grows, draw, Done shrinks; the card shows the drawing and the file has it; Copy / Upload give the edited picture. Edit: the drawings can still be moved.
- Edit right after a scrolling capture (before its file is written), Done: no prompt; the file ends up with the edit.
- Recording: trim, Done: the card shows the new length; Upload sends the trimmed file.
