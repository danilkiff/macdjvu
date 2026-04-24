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

## Development

Building from source requires [DjVuLibre](https://djvu.sourceforge.net/): `brew install djvulibre`
