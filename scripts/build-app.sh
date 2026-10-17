#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/Lid Duck.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/LidDuck" "$APP/Contents/MacOS/LidDuck"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built: $APP"
