#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lid-duck-check.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc Sources/LidDuck/Engine.swift Sources/LidDuck/LoginItemController.swift Sources/LidDuck/LoginItemService.swift scripts/EngineChecks.swift -o "$CHECK_DIR/engine-checks"
"$CHECK_DIR/engine-checks"
