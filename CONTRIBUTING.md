# Contributing to Ghosium Browser

## Scope

Contributions should preserve the current architecture and privacy/security guarantees.

## Desktop rules

- Ghosium-owned desktop executable code remains C++20.
- Do not add Tauri, WebView2 application wrappers, Rust browser cores or TypeScript/JavaScript browser runtimes.
- Keep bundled New Tab/search components script-free unless a future architecture change is explicitly approved.
- Do not add switches that disable sandboxing, certificate validation or core browser security isolation.
- Keep Ghosium-controlled product links on Ghosium-owned domains.

## Web-service rules

`search-web/` and `store-web/` target commodity shared hosting:

- PHP 8.1+
- JSON storage
- no mandatory SQL database
- no analytics/advertising SDKs
- no remote font dependency
- secure headers and protected storage paths

## Branding

User-facing product copy should use Ghosium branding. Required upstream legal attribution belongs only in the designated notice/license files and build metadata.

## Releases

Release assets must remain limited to:

- `Ghosium-Browser-Setup.exe`
- `Ghosium-Browser-Portable.exe`

The source code is represented by GitHub's release-tag source archives.

## Testing

Before merge, CI must pass browser build/smoke tests plus Search and Store PHP/JSON validation.
