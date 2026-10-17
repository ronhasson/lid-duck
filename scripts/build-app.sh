#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
mkdir -p dist
DEST="$PWD/dist/Lid Duck.app"
STAGE="$(mktemp -d "$PWD/dist/.app-build.XXXXXX")"
cleanup() {
    if [[ ! -e "$DEST" && -d "$STAGE/previous.app" ]]; then
        mv "$STAGE/previous.app" "$DEST"
    fi
    rm -rf "$STAGE"
}
trap cleanup EXIT
APP="$STAGE/Lid Duck.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LidDuck" "$APP/Contents/MacOS/LidDuck"
# SwiftPM's release executable may retain local debug/source paths. Strip debug
# symbols from the packaged copy before applying its final signature.
strip -S "$APP/Contents/MacOS/LidDuck"
cp Info.plist "$APP/Contents/Info.plist"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
if [[ -e "$DEST" ]]; then mv "$DEST" "$STAGE/previous.app"; fi
mv "$APP" "$DEST"
echo "Built: $DEST"
