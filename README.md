# Ghosium Browser

Ghosium Browser is a privacy-oriented Windows x64 distribution built directly on the open-source Chromium browser runtime.

Version **0.6.0** replaces the former custom browser shell with Chromium itself, so tabs, windows, settings, bookmarks, history, downloads, profiles, extensions, site permissions, password management, DevTools, printing and the rest of the standard desktop browser experience are provided by the Chromium browser code rather than reimplemented by Ghosium.

## Architecture

Ghosium has one custom programming-language layer: **C++**.

- `launcher/main.cpp` is the native Windows launcher.
- `extension/` contains presentation assets and a Manifest V3 declarative privacy ruleset. HTML/CSS/JSON are data and presentation resources; there is no custom JavaScript runtime.
- `CHROMIUM_REVISION` pins the official Google-hosted Chromium Windows snapshot used by a release.
- `.github/workflows/windows-build.yml` validates, assembles, smoke-tests and publishes the stable Windows package.

The Chromium runtime is downloaded only from the official `chromium-browser-snapshots` Google Storage bucket used by Chromium infrastructure. It is kept intact inside `runtime/`; the Ghosium launcher starts that runtime with a dedicated local profile and conservative privacy switches.

## Chrome-style browser capabilities

Because Ghosium now runs Chromium directly, the browser includes the familiar desktop Chromium feature set:

- multi-window and multi-tab browsing
- omnibox navigation and search
- bookmarks and bookmark manager
- history and browsing-data controls
- downloads manager
- password manager and autofill controls provided by Chromium
- per-site permissions for camera, microphone, location, notifications and other capabilities
- cookies, storage and site-data controls
- extension support and `chrome://extensions`
- developer tools
- printing and PDF output
- profiles inside the dedicated Ghosium user-data directory
- Chromium accessibility, rendering, sandboxing and process isolation
- Chromium settings and diagnostics pages

Some Google-proprietary services are intentionally not part of an open-source Chromium distribution. See [Known limitations](#known-limitations).

## Ghosium privacy defaults

The launcher applies a small set of upstream Chromium switches that are documented in Chromium source:

- sync disabled
- crash reporting disabled for the launched runtime
- background browser mode disabled
- hyperlink auditing pings disabled
- first-run and default-browser nags disabled

The bundled `Ghosium Privacy` Manifest V3 component adds:

- a local Ghosium new-tab page with no analytics or remote assets
- a static third-party tracker/advertising ruleset
- removal of common campaign and click-tracking query parameters on top-level navigation

Ghosium does **not** operate application analytics, advertising IDs, telemetry collection or a user-profile backend. Websites you visit, your DNS resolver, your selected search provider and downloaded extensions can still receive normal network requests.

Read [PRIVACY.md](PRIVACY.md) for the full data-flow model.

## Local data

The launcher uses:

```text
%LOCALAPPDATA%\Ghosium Browser\User Data
```

as Chromium's user-data directory. Browser history, bookmarks, cookies, site data, preferences and other profile information therefore stay in a dedicated local Ghosium profile unless a website or extension explicitly synchronizes its own data.

## Install

Stable releases provide:

- `Ghosium-Browser-Setup-v0.6.0.exe` — per-user Windows installer
- `Ghosium-Browser-Portable-v0.6.0.zip` — portable application files; profile data still uses `%LOCALAPPDATA%` by default
- `SHA256SUMS.txt` — release file checksums
- `BUILD-INFO.json` — exact Chromium revision and Chromium product version included in the release

Releases are published as normal stable GitHub Releases. The workflow never uses the pre-release flag.

## GitHub Packages

Every newly published stable release is also mirrored to GitHub Container Registry as an OCI release bundle:

```text
ghcr.io/bren-wp/ghosium-browser:<version>
ghcr.io/bren-wp/ghosium-browser:latest
```

The package is a distribution artifact containing the Windows release files; it is not a Linux browser container.

## Build and verification

The standard release workflow intentionally does not compile the entire Chromium source tree on a normal GitHub-hosted runner. Instead it downloads one pinned official Chromium Windows snapshot, compiles the small C++ Ghosium launcher with Microsoft's C++ toolchain already present on the runner, validates the Manifest V3 resources, runs Chromium headless smoke tests and packages the result.

For a full Chromium source build and a fully rebranded Chromium fork, see [BUILDING.md](BUILDING.md). A full Chromium Windows build requires the Chromium `depot_tools` toolchain and substantially more disk/RAM than a normal hosted CI runner provides.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — runtime boundaries and design decisions
- [BUILDING.md](BUILDING.md) — release build and full-source Chromium build paths
- [PRIVACY.md](PRIVACY.md) — privacy model and network boundaries
- [SECURITY.md](SECURITY.md) — security policy and reporting
- [CONTRIBUTING.md](CONTRIBUTING.md) — contribution rules
- [CHANGELOG.md](CHANGELOG.md) — version history
- [docs/RELEASE.md](docs/RELEASE.md) — stable release procedure
- [docs/CHROMIUM-UPDATES.md](docs/CHROMIUM-UPDATES.md) — Chromium update process
- [docs/PRIVACY-HARDENING.md](docs/PRIVACY-HARDENING.md) — privacy hardening rationale
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) — Chromium and third-party attribution notes

## Known limitations

Open-source Chromium snapshots intentionally do not include Google Chrome proprietary components. Depending on the upstream snapshot, this can include missing Google account/browser sync integration, Widevine DRM, some proprietary media codecs and Google API-backed services. Ghosium does not inject private Google API credentials to work around those restrictions.

Automatic Ghosium application updates are not performed in the background. Updating is explicit: install a newer stable Ghosium release. This avoids a permanent Ghosium updater service and keeps release provenance visible.

## License

Ghosium-authored source is licensed under the BSD 3-Clause License; see [LICENSE](LICENSE). Chromium and its dependencies retain their own licenses and notices. Release packages include Chromium license/source metadata and Chromium's built-in credits remain available from the browser.
