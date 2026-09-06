# Ghosium Browser Architecture

## Goal

Ghosium Browser keeps the Ghosium-owned desktop layer small, auditable and native while reusing a pinned upstream open-source browser engine.

## Runtime layout

```text
Ghosium-Browser.exe            native C++20 launcher
runtime/Ghosium-Engine.exe     bundled browser engine entry point
extension/                     Ghosium Privacy + branded New Tab
search-provider/               Ghosium Search default-provider component
```

The launcher owns profile selection, language selection, privacy switches, weak-PC resource limits, protected command-line arguments and process startup.

## Trust boundaries

### Ghosium-owned executable code

`launcher/main.cpp` is the only Ghosium-owned executable desktop source layer. CI rejects Rust, TypeScript and JavaScript executable source inside the desktop launcher/component paths.

### Bundled presentation/configuration

`extension/` and `search-provider/` contain HTML/CSS/JSON/Manifest resources. They remain script-free.

### Web services

`search-web/` and `store-web/` are separate PHP shared-hosting applications. They are not linked into the browser executable.

## Product links

Ghosium-controlled UI may link only to:

- `ghosium.com`
- `search.ghosium.com`
- `store.ghosium.com`

Websites entered by the user and search results are ordinary web content and are not restricted to those domains.

## Privacy

The launcher disables selected background network/reporting features while preserving the sandbox, certificate validation and core process isolation. The privacy component uses declarative request rules rather than an always-running custom script.

## Languages

Setup writes `ghosium-language.txt`. The launcher validates the locale before adding `--lang=<locale>`. Invalid/missing values fall back to `en-US`.

## Portable mode

The Portable EXE extracts the application runtime temporarily and starts the native launcher with a dedicated portable profile path. The launcher can wait for the engine process, allowing the wrapper to remove temporary runtime files when the browser closes.

## Branding boundary

Ghosium-owned surfaces use Ghosium branding. Required upstream license/attribution text remains in `THIRD_PARTY_NOTICES.md` and installed third-party license files. A future full-source engine build can replace additional upstream internal strings/resources that cannot safely be changed at the distribution layer.
