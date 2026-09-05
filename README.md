# Ghost Browser

Ghost Browser is a privacy-first Windows browser built with **Rust**, **Tauri v2**, **WebView2** and **TypeScript**, with a custom Windows 11 / Fluent browser shell.

## Current engineering baseline

- real multi-tab child WebView2 architecture
- trusted local browser chrome separated from untrusted website WebViews
- native WebView2 `WebResourceRequested` interception
- `adblock-rust` filtering before matching requests reach tracker/ad servers
- HTTP/HTTPS-only remote navigation
- common tracking query-parameter stripping
- WebRTC/media restrictions and native permission deny-by-default
- DNT + Global Privacy Control exposure
- strict Tauri capability isolation and CSP
- no Ghost Browser analytics, telemetry SDK or crash uploader
- Windows x64 portable executable + NSIS setup build workflow

## Build on Windows

```powershell
npm install
npm run tauri build -- --target x86_64-pc-windows-msvc --bundles nsis
```

The GitHub Actions workflow produces:

- `Ghost-Browser-Portable.exe`
- `Ghost-Browser-Setup.exe`
- `SHA256SUMS.txt`

## Important privacy boundary

Ghost Browser itself contains no application telemetry. The rendering engine in this edition is Microsoft WebView2. Microsoft documents that WebView2 can have required diagnostic data governed by the WebView2/Windows runtime. A literal guarantee of zero Microsoft runtime diagnostics would require replacing WebView2 with a separately maintained rendering-engine distribution.

## Production roadmap

Before public production distribution, complete Authenticode signing, signed updates, full EasyList/EasyPrivacy governance, PSL-based third-party cookie partitioning, certificate-error UI, download isolation/reputation, per-site permissions, crash recovery and automated browser/privacy regression testing.
