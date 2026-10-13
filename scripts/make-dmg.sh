#!/usr/bin/env bash
# Builds build/ScreenshotXX-<version>.dmg from a Release build, with the usual "drag to Applications" layout.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/Release/Build/Products/Release/ScreenshotXX.app
[ -d "$APP" ] || { echo "Release app not found at $APP — run: make release" >&2; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
OUT="build/ScreenshotXX-$VERSION.dmg"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT"
hdiutil create -volname "ScreenshotXX" -srcfolder "$STAGE" -ov -format UDZO -quiet "$OUT"
rm -rf "$STAGE"
shasum -a 256 "$OUT" | tee "$OUT.sha256"
echo "wrote $OUT"
