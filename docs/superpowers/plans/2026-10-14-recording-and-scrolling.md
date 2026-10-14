# Recording and scrolling capture — plan and status

Spec: `docs/superpowers/specs/2026-10-14-recording-and-scrolling-design.md`.

| # | Task | Commit | Status |
|---|---|---|---|
| 1 | Core: settings, names, video sizing, trim range, screen region | ead470c | done, tested |
| 2 | Recording to a temp file: recorder, coordinator, bar, frame, menu, hotkey, mic permission | d7c6f0f | done, checked live (full screen) |
| 3 | Video window: player, filmstrip, trim, Save / Save As, exporter | 0b947c9 | done, checked live (Save, trim buttons, discard) |
| 4 | Share and Upload for recordings | 57d1989 | done; Share checked live, Upload not sent live |
| 5 | Core: FrameSignature, ScrollStitcher, ScrollAssembler, ScrollPlanner | e089ff5 | done, tested |
| 6 | Scrolling capture in the app: injector, HUD, session, permission flow, menu, hotkey, settings | c4b4e8d | done, builds; not yet run live |
| 7 | README and docs | this commit | done |

## Still to check by hand

- A recording with the microphone on (the first one asks for the permission): voice and system sound in one track.
- Record Area and Record Window; the window bar hidden from the video in each.
- Upload from the video window: link copied, plays in Safari and Chrome; Upload then Save does not encode twice.
- Scrolling capture on a long page, with Accessibility allowed (automatic) and refused (by hand); a page with a sticky header; Esc mid-way; Enter mid-way.
- Esc during the area drag cancels (capture and recording).
