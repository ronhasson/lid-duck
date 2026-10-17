#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
zsh scripts/build-app.sh
APP="$PWD/dist/Lid Duck.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(lipo -archs "$APP/Contents/MacOS/LidDuck")"
case "$ARCH" in
    arm64|x86_64) ;;
    "x86_64 arm64"|"arm64 x86_64") ARCH=universal2 ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
mkdir -p dist/release
NAME="Lid-Duck-$VERSION-macos-$ARCH.zip"
# Preserve bundle layout and executable modes, omitting local extended attributes.
ditto --norsrc --noextattr --noqtn -c -k --keepParent "$APP" "$PWD/dist/release/$NAME"
(cd dist/release && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "Packaged: $PWD/dist/release/$NAME"
