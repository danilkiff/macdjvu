# MacDjVu

Native macOS DjVu file reader. Swift + SwiftUI, decoding via DjVuLibre.

## Disclaimer

This project was built with AI-assisted development. It was created primarily
for my personal DjVu-reading workflow, so features and priorities follow those
needs rather than a general-purpose product roadmap.

## Install

Download `MacDjVu.app.zip` from
[Releases](https://github.com/danilkiff/macdjvu/releases),
unzip, and move to `/Applications`.

### Gatekeeper

The app is not signed with an Apple Developer certificate.
macOS will block the first launch. To allow it, pick one of:

**Option A** — terminal (recommended):

```
xattr -cr /Applications/MacDjVu.app
```

**Option B** — GUI:

1. Try to open the app — macOS will show a warning
2. Open **System Settings → Privacy & Security**
3. Scroll to the bottom — click **"Open Anyway"** next to the MacDjVu message
4. Confirm in the dialog

This is a one-time step. Subsequent launches work normally.

## Requirements

- macOS 15+
- [DjVuLibre](https://djvu.sourceforge.net/): `brew install djvulibre`

## Build from source

```
swift build
bash bundle.sh
open MacDjVu.app
```

`swift run` is not supported — SPM executables lack a proper .app bundle
(no `Info.plist`, no bundle identifier), which causes SwiftUI window
management issues. Use `bundle.sh` to produce a working `MacDjVu.app`.
