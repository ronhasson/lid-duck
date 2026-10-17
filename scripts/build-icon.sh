#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p assets dist
swift scripts/render-icon.swift "$PWD/dist/AppIcon.iconset"
iconutil --convert icns --output assets/AppIcon.icns dist/AppIcon.iconset
cp dist/AppIcon.iconset/icon_512x512@2x.png assets/AppIcon.png
