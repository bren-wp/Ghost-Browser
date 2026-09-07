# Changelog

## 0.8.0

### Windows release hardening
- Hardened the NSIS bootstrap so release builds verify the exact installer toolchain instead of depending on a mutable package feed.
- Kept real Windows install and same-Setup uninstall smoke testing as a mandatory release gate.
- Added stronger verification around generated Setup and Portable executables and release artifact publication.

### Full-source readiness
- Added pinned Chromium source and Chromium-matched `depot_tools` provenance contracts.
- Added fail-closed Windows x64 self-hosted builder readiness checks, persistent workspace validation and dependency reset hardening.
- Added source branding, Windows identity, Ghosium Search, locale and product-link verification against the pinned Chromium source tree.
- Added source-built runtime and installer round-trip verification tooling, SHA-256 provenance reports and post-merge engine audits on `main`.
- The dedicated `Ghosium Full-Source Windows Build` remains a separate manual self-hosted gate; this stable release does not claim that the full Chromium source compile has completed.

### CI and supply chain
- Security-sensitive actions used by the self-hosted full-source workflow remain pinned to immutable commit SHAs.
- Post-merge `main` changes affecting engine/source branding are now re-audited on the exact production branch SHA.
- Existing release/package publication remains guarded against duplicate stable tags.

## 0.7.0

### Branding
- Ghosium-only New Tab copy and navigation.
- Ghosium-controlled product links now point only to Ghosium-owned domains.
- Engine entry executable is packaged as `Ghosium-Engine.exe`.
- User-facing documentation now uses Ghosium terminology; legally required third-party attribution remains isolated in the notices/license material.

### Search and Store
- Ghosium Search remains the default search endpoint.
- Added complete `store-web/` shared-hosting source for `store.ghosium.com`.
- Store uses PHP + JSON, no SQL database, no application JavaScript and no third-party assets.

### Languages
- Setup language chooser expanded to 30 languages.
- English is the default/fallback; Croatian is included.
- Selected installer locale now controls browser launch language.
- Portable mode stores its selected language beside the portable profile.

### Privacy and security
- Added background-networking suppression in the native launcher.
- Preserved sandbox, certificate validation and core process isolation.
- Added validated portable profile/language launcher controls.
- Setup includes Brendigo publisher metadata and local license acceptance page.

### Packaging
- Stable GitHub Releases now attach only `Ghosium-Browser-Setup.exe` and `Ghosium-Browser-Portable.exe`.
- Source code is delivered through GitHub's automatic source archives.
- Search/Store deployable source remains in the release-tag source code instead of separate web ZIP assets.

## 0.6.0

- Migrated the desktop distribution to a direct pinned upstream open-source browser engine with a small native C++ launcher.
- Added Ghosium Search shared-hosting source, declarative privacy rules and automatic Low Memory mode.
- Added stable Windows Setup/Portable build and release verification.
