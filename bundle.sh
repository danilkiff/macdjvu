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

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.macdjvu.app</string>
    <key>CFBundleName</key>
    <string>MacDjVu</string>
    <key>CFBundleDisplayName</key>
    <string>MacDjVu</string>
    <key>CFBundleExecutable</key>
    <string>MacDjVu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
</dict>
</plist>
PLIST

echo "Built: $APP"
