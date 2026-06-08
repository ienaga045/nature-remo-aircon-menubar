#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/NatureRemoMenuBar.app"
EXECUTABLE="$ROOT_DIR/.build/release/NatureRemoMenuBar"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/NatureRemoMenuBar"
cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "$APP_DIR"
