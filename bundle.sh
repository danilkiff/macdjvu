#!/usr/bin/env bash
# Build and bundle MacDjVu as a macOS .app
set -euo pipefail

APP="MacDjVu.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

swift build -c release 2>&1

rm -rf "$APP"
mkdir -p "$MACOS"

cp .build/release/MacDjVu "$MACOS/"
cp Info.plist "$CONTENTS/Info.plist"

echo "Built: $APP"
