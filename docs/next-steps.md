# Next steps — the end game

Goal: an open-source app people install with one command and use instead of the built-in macOS shortcuts.

## 1. Open source

- Public GitHub repo `austinejose1516/ScreenshotXX`, MIT licence, this README.
- Keep `Local.xcconfig` private (already git-ignored); document the signing steps (they are in the file `make gen` creates).

## 2. Release build and GitHub Releases

- `make release`: `xcodebuild -configuration Release` into `build/Release`, then `ditto -c -k --keepParent` to `ScreenshotXX.zip`.
- GitHub Actions on a `v*` tag: build, zip, attach to the release. The workflow needs the signing certificate as a secret, or it builds ad-hoc.

## 3. Homebrew

- A tap `austinejose1516/homebrew-tap` with a cask `screenshotxx` that points at the release zip and its sha256.
- Install: `brew install --cask austinejose1516/tap/screenshotxx`.
- Without Apple notarization macOS shows "cannot verify the developer"; the user right-clicks → Open once, or the cask uses `--no-quarantine`. With the Apple Developer Program (99 USD / year) add Developer ID signing + `notarytool` in the workflow and the warning goes away.

## 4. Replace the macOS screenshot shortcuts

- User side: System Settings → Keyboard → Keyboard Shortcuts → Screenshots: turn off ⇧⌘3, ⇧⌘4, ⇧⌘5. Then record them in ScreenshotXX Settings → Shortcuts (⇧⌘3 full screen, ⇧⌘4 area, ⇧⌘5 window).
- App side: a "Use the macOS shortcuts" button in Settings that records those three and opens that System Settings pane with a short note.

## 5. Speed

- Measure first: log the time from hotkey to overlay shown (`DiagnosticLog`), target under 150 ms.
- Likely wins: fetch the window list in the background after the overlay is up (window mode only needs it on hover); keep a warm `SCShareableContent` refreshed on a timer; freeze only the display under the mouse first and the others after; reuse the frozen image for the thumbnail.

## 6. Quality

- Code review pass with the thermo-nuclear-code-quality-review skill.
- App-layer tests for the capture pipeline with a fake capturer.
- In-app updates later (Sparkle) once releases exist.
