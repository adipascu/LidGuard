#!/bin/zsh
set -euo pipefail

REPO="${0:A:h:h}"
WORK="$(mktemp -d)"
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"

swift "$REPO/scripts/make-icon.swift" "$WORK/icon-1024.png"

for size in 16 32 64 128 256 512; do
  sips -z $size $size "$WORK/icon-1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon-1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
cp "$WORK/icon-1024.png" "$SET/icon_512x512@2x.png"

iconutil -c icns "$SET" -o "$REPO/Resources/AppIcon.icns"
rm -rf "$WORK"
print -r -- "wrote $REPO/Resources/AppIcon.icns"
