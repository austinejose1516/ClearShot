#!/usr/bin/env bash
# Builds ClearShot/Resources/AppIcon.icns from ClearShot/Resources/AppIcon-source.png (square PNG, 1024 px ideal).
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=ClearShot/Resources/AppIcon-source.png
TMP=$(mktemp -d)
mkdir -p "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$SRC" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$SRC" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o ClearShot/Resources/AppIcon.icns
rm -rf "$TMP"
echo "wrote ClearShot/Resources/AppIcon.icns"
