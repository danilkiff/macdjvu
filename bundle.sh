#!/usr/bin/env bash
# Build and bundle MacDjVu as a macOS .app
set -euo pipefail

APP="MacDjVu.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

swift build -c release 2>&1

HELPERS="$CONTENTS/Helpers"

# Vendor DjVuLibre tools if not already present
if [ ! -f vendor/bin/djvused ]; then
    bash scripts/vendor-djvulibre.sh
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$HELPERS/bin" "$HELPERS/lib"

cp .build/release/MacDjVu "$MACOS/"
cp Info.plist "$CONTENTS/Info.plist"

# Bundle DjVuLibre helpers
cp vendor/bin/djvused vendor/bin/ddjvu "$HELPERS/bin/"
cp vendor/lib/*.dylib "$HELPERS/lib/"

# Ad-hoc codesign bundled binaries and libraries
codesign --force --sign - "$HELPERS/lib/"*.dylib
codesign --force --sign - "$HELPERS/bin/"*

# Compile asset catalog (app icon with light/dark variants)
xcrun actool Assets.xcassets \
    --compile "$RESOURCES" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon AppIcon \
    --output-partial-info-plist /dev/null 2>&1

echo "Built: $APP"
