# MacDjVu

Native macOS DjVu file reader. Swift + SwiftUI, decoding via DjVuLibre.

## Requirements

- macOS 15+
- [DjVuLibre](https://djvu.sourceforge.net/): `brew install djvulibre`

## Build & Run

```
swift build
bash bundle.sh
open MacDjVu.app [file.djvu]
```

`swift run` is not supported — SPM executables lack a proper .app bundle
(no `Info.plist`, no bundle identifier), which causes SwiftUI window
management issues. Use `bundle.sh` to produce a working `MacDjVu.app`.

## Test

```
swift test
```

## License

[GPL-3.0](LICENSE)
