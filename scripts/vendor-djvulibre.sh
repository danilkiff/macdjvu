#!/usr/bin/env bash
# Vendor DjVuLibre CLI tools and their non-system dylib dependencies.
# Rewrites load paths so everything resolves within the app bundle:
#   Contents/Helpers/bin/{djvused,ddjvu}
#   Contents/Helpers/lib/*.dylib
set -euo pipefail

VENDOR_DIR="$(cd "$(dirname "$0")/.." && pwd)/vendor"
rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR/bin" "$VENDOR_DIR/lib"

DJVU_PREFIX="$(brew --prefix djvulibre)"
JPEG_PREFIX="$(brew --prefix jpeg-turbo)"
TIFF_PREFIX="$(brew --prefix libtiff)"
ZSTD_PREFIX="$(brew --prefix zstd)"
XZ_PREFIX="$(brew --prefix xz)"

# --- Copy binaries ---
cp "$DJVU_PREFIX/bin/djvused" "$VENDOR_DIR/bin/"
cp "$DJVU_PREFIX/bin/ddjvu"   "$VENDOR_DIR/bin/"

# --- Copy dylibs (exact versioned names from otool -L) ---
cp "$DJVU_PREFIX/lib/libdjvulibre.21.dylib" "$VENDOR_DIR/lib/"
cp "$JPEG_PREFIX/lib/libjpeg.8.dylib"       "$VENDOR_DIR/lib/"
cp "$TIFF_PREFIX/lib/libtiff.6.dylib"       "$VENDOR_DIR/lib/"
cp "$ZSTD_PREFIX/lib/libzstd.1.dylib"       "$VENDOR_DIR/lib/"
cp "$XZ_PREFIX/lib/liblzma.5.dylib"         "$VENDOR_DIR/lib/"

# --- Make everything writable (Homebrew installs are read-only) ---
chmod u+w "$VENDOR_DIR/bin/"* "$VENDOR_DIR/lib/"*.dylib

# --- Fix dylib install names ---
for lib in "$VENDOR_DIR/lib/"*.dylib; do
    name=$(basename "$lib")
    install_name_tool -id "@loader_path/$name" "$lib"
done

# --- Rewrite load paths in binaries → @executable_path/../lib/ ---
for bin in "$VENDOR_DIR/bin/"*; do
    for lib in "$VENDOR_DIR/lib/"*.dylib; do
        name=$(basename "$lib")
        old_path=$(otool -L "$bin" | grep "$name" | head -1 | awk '{print $1}' || true)
        if [ -n "$old_path" ]; then
            install_name_tool -change "$old_path" "@executable_path/../lib/$name" "$bin"
        fi
    done
done

# --- Rewrite inter-library references → @loader_path/ ---
for lib in "$VENDOR_DIR/lib/"*.dylib; do
    lib_name=$(basename "$lib")
    for dep in "$VENDOR_DIR/lib/"*.dylib; do
        dep_name=$(basename "$dep")
        [ "$lib_name" = "$dep_name" ] && continue
        old_path=$(otool -L "$lib" | grep "$dep_name" | head -1 | awk '{print $1}' || true)
        if [ -n "$old_path" ] && [ "$old_path" != "@loader_path/$dep_name" ]; then
            install_name_tool -change "$old_path" "@loader_path/$dep_name" "$lib"
        fi
    done
done

# --- Strip debug symbols ---
strip -x "$VENDOR_DIR/bin/"* 2>/dev/null || true
strip -x "$VENDOR_DIR/lib/"*.dylib 2>/dev/null || true

echo "Vendored djvulibre tools to $VENDOR_DIR"
