# DjVu Test Fixtures

Small DjVuLibre-generated files used by integration tests.

- `single-page.djvu`: one page, `40x30`.
- `two-page.djvu`: bundled document with pages `40x30` and `24x48`.

The fixtures are intentionally tiny so tests exercise real `djvused`/`ddjvu`
paths without adding meaningful repository size.
