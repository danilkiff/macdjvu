# MacDjVu

Native macOS DjVu file reader. Swift + SwiftUI, decoding via DjVuLibre.

## Requirements

- macOS 15+
- [DjVuLibre](https://djvu.sourceforge.net/): `brew install djvulibre`

## Build & Run

```
swift build
swift run MacDjVu [file.djvu]
```

To create a standalone .app bundle:

```
bash bundle.sh
open MacDjVu.app
```

## Test

```
swift test
```

## License

[GPL-3.0](LICENSE)
