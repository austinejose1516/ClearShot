# ClearShot: the Frame panel for recordings

> Austin, 2026-10-22: "add the same frame options for video" → "go, build it". Claude's calls are marked.

## What the user sees

1. The video editor's top bar gets a **Frame** switch, like the screenshot editor's. On, the same panel slides in on the right: background (none, colour, 8 gradients, your own image), padding, corner radius, shadow, Reset frame. Opening it on an untouched frame applies the starter (padding 64, corners 16, shadow 40, Ocean gradient), as for screenshots.
2. The player shows the framed video at once, for the whole clip: the recording sits on the background with its padding, rounded corners and shadow. The picture gets bigger by the padding on each side.
3. Blur boxes keep working and sit where the video is inside the frame.
4. **Done** (⌘S) writes the framed (and trimmed, blurred) video into the recording's file at the new size. The card takes the new first frame and size, so Edit again opens the file as it is. Closing without Done keeps the frame while the card is open.
5. Background **None** shows black around the video (a video has no see-through).

## How it works

- `FrameStyle` and `CanvasLayout` from Core are reused as they are: the canvas is the video plus padding on each side, the video at (padding, padding).
- Output size: `VideoEncoding.Settings.resized(to:)` gives even sides and a bitrate scaled by the pixel count, within the usual limits. The composition's render size and the writer's size are this.
- One custom compositor (`AVVideoCompositing`) draws every frame for both the player and the exporter: the blur boxes on the source, then the source placed on a cached "plate" (background + shadow) through a rounded-rectangle mask. The plate is built once per frame style and size, so a frame costs one translate and one masked blend. This replaces the Core Image filter initializer, which cannot change the output size.
- Changing padding changes the output size, so the player's composition is rebuilt then; every other change updates the compositor's shared state and seeks to redraw.
- `Capture.saved(videoDuration:poster:encoding:at:)` lets the card keep the new size.

## Claude's calls

- Same panel, same ranges and starter as screenshots; no extra controls.
- Background None → black.
- Shadow goes down by a third of its radius, like the screenshot editor.

## Not in this change

- Per-clip or animated frames; a frame on the live recording.
