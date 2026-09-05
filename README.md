# Ghost Browser

Ghost Browser is a privacy-first Windows browser built with **Rust**, **Tauri v2**, **Microsoft WebView2** and **TypeScript**, with a custom Windows 11 / Fluent browser shell.

The project is intentionally designed as a browser shell with isolated remote child WebViews, not as a generic Tauri page wrapper.

## Security and privacy baseline

- real multi-tab child WebView2 architecture
- trusted local browser chrome separated from untrusted website WebViews
- remote website WebViews are excluded from Tauri capabilities and native IPC privileges
- native WebView2 `WebResourceRequested` interception
- `adblock-rust` filtering before matching requests reach tracker/ad servers
- WebView2 resource contexts mapped to adblock request types (`script`, `image`, `font`, `stylesheet`, XHR/fetch, websocket, media...)
- HTTP/HTTPS-only top-level remote navigation
- URL user-info rejection and common tracking query-parameter stripping
- DNT and Global Privacy Control exposed in JavaScript and sent as native request headers
- WebRTC/media restrictions and native permission deny-by-default
- strict local-shell CSP, Tauri global API disabled, asset protocol disabled
- autofill disabled in remote tab WebViews
- production WebView2 DevTools disabled
- no Ghost Browser analytics SDK, advertising ID, telemetry SDK or crash uploader

## Browser UX baseline

- Windows 11 / Fluent-inspired custom titlebar and browser chrome
- tabs, new tab, omnibox, Back, Forward and Reload
- keyboard shortcuts including `Ctrl+L`, `Ctrl+T`, `Ctrl+W`, `F5` and `Ctrl+J`
- Ghost Shields privacy panel
- session download panel driven by the native browser download hook
- responsive shell for smaller Windows window sizes

## Build on Windows

Requirements:

- Windows 10/11 x64
- Node.js 22+
- stable Rust toolchain with `x86_64-pc-windows-msvc`
- Visual Studio C++ Build Tools / Windows SDK

```powershell
npm install
npm run audit
npm run build
cargo check --manifest-path src-tauri/Cargo.toml --target x86_64-pc-windows-msvc
npm run tauri build -- --target x86_64-pc-windows-msvc --bundles nsis
```

The GitHub Actions workflow performs the frontend audit/build, Rust/WebView2 compiler gate and NSIS packaging and produces:

- `Ghost-Browser-Portable.exe`
- `Ghost-Browser-Setup.exe`
- `SHA256SUMS.txt`

## Privacy boundary

Ghost Browser itself contains no application telemetry, profiling backend or advertising integration. The rendering engine in this edition is Microsoft WebView2. Web requests made by the user necessarily reach the selected websites and search provider, and the WebView2/Windows runtime can be subject to Microsoft's required diagnostic-data behavior.

A literal guarantee that the rendering runtime itself never communicates with Microsoft would require replacing WebView2 with a separately maintained Chromium/CEF or other rendering-engine distribution. Ghost Browser does not claim otherwise.

## Code signing and SmartScreen

The current development binaries are **not Authenticode-signed**. Setting `publisher` metadata in the installer does not constitute a digital signature. Until a trusted code-signing certificate and signing pipeline are configured, Windows can show **Unknown Publisher** and/or SmartScreen reputation warnings.

## Production roadmap

The current codebase is an engineering baseline, not a claim of Chrome-level maturity. Before broad public production distribution, the roadmap includes:

- Authenticode signing and signed update metadata
- managed download completion/progress, isolation and reputation checks
- governed EasyList/EasyPrivacy-compatible filter-list update pipeline
- PSL-based third-party cookie isolation/partitioning
- certificate-error UX
- per-site permission decisions and persistence
- session and crash recovery
- bookmarks, history and private windows
- browser/privacy regression and Web Platform compatibility tests
- reproducible dependency lockfiles and supply-chain verification

## License and third-party components

Before public release, add the final project license and preserve all license/notice obligations for Tauri, WebView2 integration libraries, `adblock-rust` and other dependencies.
