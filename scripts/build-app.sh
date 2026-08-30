#!/bin/zsh
set -euo pipefail

REPO="${0:A:h:h}"
APP="$REPO/build/LidGuard.app"
CONFIG=release

cd "$REPO"
swift build -c "$CONFIG" --arch arm64 --arch x86_64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)/LidGuard" "$APP/Contents/MacOS/LidGuard"
cp "$REPO/Resources/Info.plist" "$APP/Contents/Info.plist"

if [[ -f "$REPO/Resources/AppIcon.icns" ]]; then
  cp "$REPO/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - --options runtime "$APP" 2>/dev/null || codesign --force --deep --sign - "$APP"

print -r -- "built $APP"
codesign -dv "$APP" 2>&1 | grep -E "Identifier|Signature" || true
