# Building Ghosium Browser

There are two supported build models.

## A. Standard Ghosium distribution build

This is the build used by GitHub Actions and stable releases.

Requirements on Windows x64:

- Visual Studio C++ toolchain
- PowerShell
- NSIS
- network access to the official Chromium snapshot bucket

The workflow performs these operations automatically. To reproduce them manually:

1. Read `VERSION` and `CHROMIUM_REVISION`.
2. If `CHROMIUM_REVISION` contains `latest`, resolve `https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/LAST_CHANGE` once and use that exact numeric revision for the whole build.
3. Download `Win_x64/<revision>/chrome-win.zip` from the same official bucket.
4. Extract the archive and place Chromium files under `staging/runtime/`.
5. Copy `extension/` to `staging/extension/`.
6. Compile `launcher/main.cpp` for x64 with optimization, stack protection, Control Flow Guard, DEP/ASLR and CET compatibility enabled.
7. Copy the launcher to `staging/Ghosium-Browser.exe`.
8. Run `Ghosium-Browser.exe --ghosium-self-test`.
9. Run the bundled `runtime/chrome.exe` headlessly against a local data URL as a runtime smoke test.
10. Package `staging/` as the portable ZIP and build the NSIS per-user installer.
11. Generate SHA-256 hashes for every published binary/archive.

The exact automated commands are the source of truth in `.github/workflows/windows-build.yml`.

## B. Full Chromium source build

Use this path when changing Chromium-native UI, product strings, icons, preferences or browser internals rather than only the distribution layer.

Upstream Chromium's Windows documentation requires a Windows x86-64 machine, an appropriate Visual Studio installation, `depot_tools`, and a large source/build volume. More than 16 GB RAM is recommended and the checkout/build should have at least roughly 100 GB free disk space.

High-level process:

```text
install depot_tools
fetch chromium
cd src
git checkout <pinned Chromium tag or commit>
gclient sync
gn gen out/Ghosium --args="is_official_build=true is_component_build=false symbol_level=0"
autoninja -C out/Ghosium chrome mini_installer
```

For Ghosium, apply reviewed product/branding/privacy patches only after pinning the Chromium revision. Keep Ghosium-specific native changes in C++/Chromium resource files and avoid introducing another application runtime.

## Release reproducibility

A stable release must include:

- Ghosium version
- numeric Chromium snapshot revision
- Chromium product version
- Chromium source revision when available from the snapshot `REVISIONS` metadata
- SHA-256 of the downloaded upstream Chromium archive
- SHA-256 of each Ghosium release artifact

Those values are emitted to `BUILD-INFO.json` and related text files in every release package.

## Version synchronization

`VERSION` is the single Ghosium version source. The extension manifest version must match it. CI rejects mismatches.

## Do not publish from an unpinned build

`latest` is allowed temporarily on a development branch only so CI can resolve the newest official snapshot and report its numeric revision. Before a production release, replace `latest` in `CHROMIUM_REVISION` with the exact validated numeric revision and rerun CI.
