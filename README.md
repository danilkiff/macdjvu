# DjVu reader for macOS

> [!IMPORTANT]
> Scratch-built for personal use with AI assistance.
> Features land when I need them.

## Requirements

- macOS 15+

## Install

Download `MacDjVu.dmg` from [Releases](https://github.com/danilkiff/macdjvu/releases), open, and drag to `/Applications`.
DjVuLibre is bundled — no extra dependencies needed.

The app is not signed with an Apple Developer certificate.
macOS will block the first launch. To allow it, run: `xattr -cr /Applications/MacDjVu.app`.

## FAQ

**Why not the App Store?**

App Store requires Apple Developer Program ($99/year) and App Sandbox.
Sandbox blocks the bundled CLI tools from accessing user-selected files directly, which would require rewriting the renderer to use the DjVuLibre C API with a temp-file workaround.
Not worth the complexity for a personal-use app.

**Why `xattr -cr`?**

The app is not notarized. Notarization also requires the $99/year Developer Program. 

## Development

Building from source requires [DjVuLibre](https://djvu.sourceforge.net/): `brew install djvulibre`
