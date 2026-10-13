<p align="center">
  <img src="ClearShot/Resources/AppIcon-source.png" width="128" alt="ClearShot icon">
</p>

<h1 align="center">ClearShot</h1>

<p align="center">
  Free and open-source screenshots for your Mac.<br>
  Capture an area, a window or the full screen, then mark it up in a fast, native editor.
</p>

```bash
brew install --cask austinejose1516/tap/clearshot
```

Or [download the latest DMG](https://github.com/austinejose1516/ClearShot/releases/latest).

<p align="center">
  <a href="https://github.com/austinejose1516/ClearShot/releases/latest"><img src="https://img.shields.io/github/v/release/austinejose1516/ClearShot?label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-black?logo=apple" alt="macOS 26 or later">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-green" alt="MIT licence"></a>
</p>

---

## Install

ClearShot installs with [Homebrew](https://brew.sh):

```bash
brew install --cask austinejose1516/tap/clearshot
```

| To | Run |
|---|---|
| Update to the newest version | `brew upgrade --cask clearshot` (or just `brew upgrade`) |
| Uninstall | `brew uninstall --cask clearshot` |
| Uninstall and remove its settings and log | `brew uninstall --zap --cask clearshot` |

**No admin rights?** Install into your own Applications folder instead of `/Applications`. Add this line to `~/.zshrc` once, so installs and upgrades both go there:

```bash
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
```

**Without Homebrew:** download `ClearShot-<version>.dmg` from the [latest release](https://github.com/austinejose1516/ClearShot/releases/latest), open it and drag ClearShot into Applications. **Check for Updates…** in the menu bar tells you when a newer DMG is out.

**First launch.**

1. The app is not notarized yet, so the first time right-click ClearShot in Applications and choose **Open**.
2. The welcome window asks for **Screen Recording** access. Click **Allow Access** and turn ClearShot on in System Settings.
3. Quit ClearShot from the menu bar and open it again. Press **⌃⇧A** to capture.

Needs macOS 26 (Tahoe) or later. ClearShot lives in the menu bar; it has no account and keeps your screenshots on your Mac. It only talks to the network for a once-a-day check for a newer version on GitHub (Settings → Updates turns it off; **Check for Updates…** in the menu bar asks right away), and for **Upload**, which sends to your own cloud bucket and only when you press it.

## Features

### Capture

- **Area** — the screen freezes and dims; drag a box and see its size as you go. Press **Space** to switch to window mode, **Esc** to cancel.
- **Window** — hover to highlight a window, click to capture it with its shadow and rounded corners.
- **Full screen** — the display under the mouse.
- Every capture flashes the screen, plays the shutter sound, goes to the clipboard and is saved to the Desktop as PNG or JPEG (change the folder and format in Settings).

### Quick Access card

A card slides up at the bottom-left after each capture. Hover it for a glass bar with **Edit**, **Copy**, **Share**, **Upload**, **Reveal in Finder** and **Move to Trash**, plus close and the image size. Drag the thumbnail straight into Finder, Slack or any app. Cards can close themselves after a few seconds (Settings).

### Share and upload

- **Share** (editor and card) opens the macOS Share menu: AirDrop, Messages, Mail, Slack and whatever else is installed.
- **Upload** (editor and card) sends the image to your own [Cloudflare R2](https://developers.cloudflare.com/r2/) bucket under a short random name, such as `images/k3x9p2m7qa.png`, and copies the public link. Set it up once in Settings → Cloud: enter the Account ID, Access Key ID, Secret Access Key (kept in your Keychain), Bucket and Public URL, then press **Connect**. Connect uploads a tiny file, opens it through the Public URL and deletes it, so you know links will work. The card shows the upload progress and keeps a **Copy link** button afterwards.

### Editor

| Tool | What it does |
|---|---|
| Select | Click to select (inside rectangles and ellipses too), drag to move, drag a dot to resize |
| Line, Arrow | Straight lines, with or without an arrowhead |
| Curved arrow | Drag a straight arrow, then drag the middle dot anywhere to bend it; the head follows the curve |
| Pen | Freehand, smoothed |
| Highlighter | A wide, see-through marker that keeps the text under it crisp; remembers its own colour and width |
| Rectangle, Ellipse | Outline or filled; rectangles can have rounded corners |
| Text | Drag a box to set the size, or click; type; **Enter** finishes, **⌘Enter** adds a line; bold, italic, underline and boxed styles |
| Speech bubble | Draw the bubble, type, drag its tail |
| Step number | Click to place 1, 2, 3…; pick the size or drag a corner dot |
| Blur | Pixelate or blur anything private |
| Crop | Drag the part to keep, then **Crop** or **Enter** |

- The toolbar only shows the settings that apply: colour (a dropdown with presets and any custom colour), opacity, width slider, fill, corners, arrowhead, text size, bold / italic / underline, boxed, step size, blur mode.
- Shape and text tools hand back to the pointer after one use, so you can adjust right away. Pen, Highlighter, Step and Blur stay on; a plain click with any tool goes back to the pointer.
- Full undo and redo. Annotations can also sit in the padding, for example a header above the screenshot. Zoom with ⌘+ / ⌘−, the zoom menu or a trackpad pinch.
- **Frame** panel: background (none, colour, 8 gradients, or your own image), padding, rounded corners and a shadow slider.
- **Save** writes back into the screenshot file and closes the editor; **Save As…** writes a new PNG or JPEG; **Copy** puts the result on the clipboard and closes; **Share** opens the Share menu and keeps the editor open; **Upload** sends it to your bucket, copies the link and closes.

### Themes and settings

- **Appearance**: System, Light or Dark, and an accent colour: Ocean, Violet, Sunset, Forest or Graphite.
- Save folder, file format, clipboard, shutter sound, mouse pointer in captures, card duration, launch at login.
- **Cloud**: the Cloudflare R2 bucket that Upload sends to, with Connect / Disconnect.
- Change any shortcut, or let ClearShot take over the macOS keys **⇧⌘3 / ⇧⌘4 / ⇧⌘5** (turn the built-in ones off first in System Settings → Keyboard → Keyboard Shortcuts → Screenshots).

## Keyboard shortcuts

| Where | Keys | Action |
|---|---|---|
| Anywhere | ⌃⇧A | Capture area (Space switches to window) |
| Anywhere | ⌃⇧W | Capture window |
| Anywhere | ⌃⇧F | Capture full screen |
| Editor | ⌘Z / ⇧⌘Z | Undo / redo |
| Editor | ⌫ | Delete the selection |
| Editor | ⌘A | Select all |
| Editor | ⌘C | Copy the result and close |
| Editor | ⌘S / ⇧⌘S | Save and close / Save As… |
| Editor | ⌘+ / ⌘− | Zoom in / out |
| Editor | Enter | Apply the crop |
| Editor | Esc | Clear the selection and go back to the pointer |
| Editor, typing text | ⌘B / ⌘I / ⌘U | Bold / italic / underline |
| Typing text | Enter / ⌘Enter | Finish / new line |

## Build from source

Needs Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make build      # generate the Xcode project and build Debug
make run        # build and launch
make core-test  # Swift Testing suite for the Core package
make check      # tests + build
make dmg        # Release build + build/ClearShot-<version>.dmg
```

`make gen` creates `Local.xcconfig` (git-ignored) for your signing settings. Follow the comments inside it once: a stable signature keeps the Screen Recording permission across rebuilds.

### Project layout

- `Packages/ClearShotCore` — the logic, with no UI: settings, capture geometry, annotations, the editor session (mouse, styling, text editing, crop), layout, undo, files. Tested with `swift test`.
- `ClearShot/` — the app: capture with ScreenCaptureKit, overlays, the Quick Access card, the editor views, settings.
- `scripts/make-icns.sh` — builds the app icon from `ClearShot/Resources/AppIcon-source.png`.
- `~/Library/Logs/ClearShot.log` — a small diagnostics log (Settings → Show Log in Finder).

### Releasing

1. Bump `MARKETING_VERSION` in `project.yml`.
2. Push a tag such as `v0.5.0`. GitHub Actions builds and signs the DMG and publishes it as a release. Homebrew downloads that file, so keep it on the release.
3. Put the new version and DMG checksum into `Casks/clearshot.rb` in [homebrew-tap](https://github.com/austinejose1516/homebrew-tap) (a copy lives in `packaging/homebrew/`). Users then get it with `brew upgrade`.

## Contributing

Ideas, bug reports and pull requests are welcome. [Open an issue](https://github.com/austinejose1516/ClearShot/issues) to start. Please run `make check` before sending a pull request.

## Licence

[MIT](LICENSE) © 2026 Austine Jose
