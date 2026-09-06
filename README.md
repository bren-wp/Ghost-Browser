# Ghosium Browser

Ghosium Browser is a privacy-focused Windows browser with a Rust/Tauri browser core, a custom Windows 11 interface and the Windows Chromium/WebView2 rendering runtime.

## Current browser core

- multi-tab child WebView architecture with the trusted Ghosium chrome isolated from remote website WebViews
- Memory Saver with a bounded live-renderer budget and transparent tab restore
- native request interception with bundled local ad/tracker filtering
- WebView2 Strict tracking prevention
- removal of common tracking parameters before navigation
- HTTP/HTTPS navigation validation and restricted internal navigation
- blocked hyperlink-auditing PING requests
- DNT and Global Privacy Control signals
- camera, microphone and geolocation use the normal browser permission flow only after a user action; permission decisions are not persisted by Ghosium
- high-risk device APIs remain restricted by default
- remote pages cannot use Tauri IPC, WebView host objects or WebMessage
- password autosave, general autofill and remote DevTools are disabled
- no Ghosium analytics SDK, advertising identifier, profiling system or Ghosium crash uploader
- optimized Windows x64 Portable.exe and NSIS Setup.exe builds with SHA256 checksums

## Windows build

```powershell
npm install
npm run tauri build -- --target x86_64-pc-windows-msvc --bundles nsis
```

The Windows workflow audits frontend dependencies, compiles the frontend and Rust core, runs the high-tab-count scheduler tests, creates the optimized Windows executable and NSIS installer, calculates SHA256 checksums and publishes release assets from `main`.

## Privacy boundary

Ghosium Browser does not operate application telemetry, analytics, advertising or user-profiling infrastructure. Websites that you intentionally visit necessarily receive normal web requests, and text web searches require a search-index backend unless Ghosium operates its own crawler and web index.

This compact Windows edition uses the system Microsoft WebView2 runtime rather than bundling an entire rendering engine. That keeps the Ghosium download small and provides Chromium-class site compatibility, but Microsoft documents required WebView2 diagnostic data at the runtime level. A literal guarantee of zero Microsoft runtime diagnostics would require a separately maintained bundled rendering engine and a substantially larger distribution.

## Rendering-engine direction

Ghosium keeps browser behavior, privacy policy, tab lifecycle and trusted UI separated from rendering-specific code. A future bundled Gecko/Firefox or Servo-derived edition can therefore be evaluated without coupling the browser UI to a search provider. Gecko is mature but significantly increases distribution size and maintenance requirements; Servo remains promising for a Rust-native engine but is not yet the compatibility baseline used for this production Windows edition.
