# Ghosium Browser Architecture

## Goal

Ghosium is a Chromium-native distribution, not a browser rendered inside another application's embedded webview. The browser runtime is upstream Chromium and the only Ghosium-owned executable desktop layer is a small C++20 launcher.

## Desktop runtime

1. `Ghosium-Browser.exe` validates bundled files and prepares the dedicated profile.
2. The launcher applies Windows image-load mitigations.
3. It starts the pinned `runtime/chrome.exe` Chromium binary.
4. `extension/` is loaded for local new-tab presentation and declarative privacy filtering.
5. `search-provider/` is loaded as a separate single-purpose search-provider override pointing to `search.ghosium.com`.
6. Chromium itself owns tabs, navigation, renderer processes, sandboxing, settings, downloads, permissions, extensions and DevTools.

No remote page receives an IPC bridge into the C++ launcher.

## Protected command line

The launcher does not forward caller switches that would replace the profile/extensions or weaken critical browser security. It filters custom profile/extension overrides, sandbox disabling, web-security disabling, certificate-error bypass, insecure-content bypass and remote-debugging switches. Ordinary URLs and normal Chromium arguments are forwarded.

## Performance modes

`GlobalMemoryStatusEx` determines installed physical memory. At 8 GiB or below, Low Memory mode limits Chromium to six renderer processes and a 128 MiB disk-cache budget. Balanced mode leaves renderer/cache policy to Chromium. Security features are not disabled as a memory optimization.

## Search service boundary

`search-web/` is intentionally separate from the desktop executable. It is PHP because it must run on common shared hosting, while the browser remains C++/Chromium. The service defaults to a local JSON index and can optionally proxy a privately configured compatible JSON result API.

The browser never contains a provider API key.

## Release provenance

`CHROMIUM_REVISION` pins the Windows Chromium snapshot. CI records the Chromium product version, Chromium source Git SHA and SHA-256 of the downloaded upstream archive in `BUILD-INFO.json` and `CHROMIUM-REVISION.txt`.
