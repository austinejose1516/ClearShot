# ScreenshotXX

A small native macOS screenshot app in the spirit of CleanShot X: capture, a floating card at the bottom-left, and an editor with lines, arrows, curves, text, speech bubbles, step numbers, blur, and a frame (padding, rounded corners, shadow, backgrounds).

## Use

| Action | Default shortcut |
|---|---|
| Capture area | ⌃⇧A (Space switches to window mode) |
| Capture window | ⌃⇧W |
| Capture full screen | ⌃⇧F |

Shortcuts, save folder, format, clipboard, sound, card auto-close and launch at login live in Settings (menu bar icon → Settings…).

In the editor: ⌘Z / ⇧⌘Z undo and redo, Delete removes, ⌘C copies the result, ⌘S saves into the capture file, Enter applies a crop, Esc cancels.

## Install

- **DMG:** download `ScreenshotXX-<version>.dmg` from the Releases page, open it, drag ScreenshotXX to Applications. The first time, right-click the app → Open (the build is not notarized yet).
- **Homebrew:** `brew install --cask austinejose1516/tap/screenshotxx` (tap: `austinejose1516/homebrew-tap`).

## Build

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make build      # generates the project and builds Debug
make run        # builds and launches
make core-test  # Swift Testing suite for the Core package
make check      # tests + build
make dmg        # Release build + build/ScreenshotXX-<version>.dmg
```

`Local.xcconfig` (git-ignored, created by `make gen`) holds the per-machine signing settings. Follow the comments inside it once; a stable signature keeps the Screen Recording permission across rebuilds.

## Layout

- `Packages/ScreenshotXXCore` — pure logic (settings, geometry, annotations, layout, undo, files). Tested with `swift test`.
- `ScreenshotXX/` — the app: capture (ScreenCaptureKit), overlay panels, Quick Access card, editor.
- `scripts/make-icns.sh` — builds the app icon from `ScreenshotXX/Resources/AppIcon-source.png`.
- `~/Library/Logs/ScreenshotXX.log` — diagnostics log (Settings → Show Log in Finder).
