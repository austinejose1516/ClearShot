#!/usr/bin/env bash
# Builds ScreenshotXX/Resources/AppIcon.icns from ScreenshotXX/Resources/AppIcon-source.png (square PNG, 1024 px ideal).
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=ScreenshotXX/Resources/AppIcon-source.png
TMP=$(mktemp -d)
mkdir -p "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$SRC" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$SRC" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o ScreenshotXX/Resources/AppIcon.icns
rm -rf "$TMP"
echo "wrote ScreenshotXX/Resources/AppIcon.icns"
