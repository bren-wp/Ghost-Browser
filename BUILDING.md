# Building Ghosium Browser

## Production distribution build

The supported release path is `.github/workflows/windows-build.yml` on GitHub-hosted Windows x64. It:

1. validates branding, architecture, manifests and the Ghosium Search endpoint;
2. validates all PHP/JSON files in `search-web/` on Linux;
3. downloads the exact numeric Chromium snapshot from official Chromium infrastructure;
4. records upstream version/source/hash metadata;
5. compiles `launcher/main.cpp` with MSVC C++20 and Windows binary mitigations;
6. runs launcher self-test and Chromium headless smoke test;
7. creates Portable ZIP, NSIS Setup EXE and shared-hosting Search ZIP;
8. computes SHA-256 checksums;
9. publishes a normal stable GitHub Release from `main`;
10. mirrors the verified files to GitHub Packages/GHCR.

## Desktop source language

Do not add Rust, TypeScript, JavaScript, Electron, Tauri or WebView application code to the desktop browser layer. The Ghosium-owned executable layer is C++20. HTML/CSS/JSON are allowed as script-free browser resources.

`search-web/` is a separate server-side PHP application because its deployment target is shared hosting.

## Local C++ launcher build

On Windows with Visual Studio C++ tools:

```powershell
cl.exe /std:c++20 /O2 /W4 /EHsc /DUNICODE /D_UNICODE /GS /sdl /guard:cf /MT launcher\main.cpp /Fe:Ghosium-Browser.exe /link /SUBSYSTEM:WINDOWS /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA /GUARD:CF /CETCOMPAT user32.lib shell32.lib
```

A usable runtime also requires the pinned Chromium snapshot plus `extension/` and `search-provider/` beside the launcher.

## Full Chromium source fork

A future fully source-branded fork may apply Ghosium patches directly inside Chromium and build with Chromium's `depot_tools`/GN/Ninja toolchain. That path is intentionally separate from the normal GitHub-hosted distribution build because full Chromium builds require far more disk, RAM and CPU time.
