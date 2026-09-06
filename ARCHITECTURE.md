# Architecture

## Goal

Ghosium Browser is a Windows distribution of the upstream open-source Chromium browser with a minimal Ghosium-owned layer.

The design deliberately avoids rebuilding browser fundamentals that Chromium already implements well. This reduces custom attack surface and gives users the familiar Chromium/Chrome-style browser model for tabs, settings, extensions, site permissions, password management, history and downloads.

## Components

### 1. Chromium runtime

`runtime/` is created only during CI packaging. It is not committed to this repository.

The runtime comes from the official Google-hosted Chromium snapshot archive for Windows x64. The release records the exact snapshot position and Chromium source revision.

### 2. Native launcher

`launcher/main.cpp` is the only Ghosium-authored programming-language runtime component.

Responsibilities:

- locate the bundled Chromium executable
- create/use the dedicated local Ghosium user-data directory
- load the bundled Ghosium Manifest V3 component
- apply conservative privacy-oriented Chromium switches
- forward normal browser command-line arguments
- refuse caller overrides that would replace the Ghosium profile/component path or re-enable crash reporting/sync through the launcher
- fail closed when required runtime files are missing

The launcher does not render webpages, implement networking or parse web content.

### 3. Ghosium Privacy component

`extension/` contains a Manifest V3 package with no custom JavaScript.

It provides:

- the branded new-tab page
- a local static tracker/ad ruleset
- top-level tracking-parameter cleanup

The rules are declarative and processed by Chromium's extension/network machinery.

### 4. Local profile

The profile root is:

```text
%LOCALAPPDATA%\Ghosium Browser\User Data
```

Chromium may create multiple profiles below that root through its normal profile UI.

### 5. Release pipeline

The Windows CI job:

1. validates repository invariants;
2. resolves or reads the pinned Chromium snapshot revision;
3. downloads Chromium from the official snapshot bucket;
4. records Chromium version/source metadata;
5. compiles the C++ launcher;
6. assembles the Ghosium distribution;
7. validates the extension and privacy rules;
8. runs self-tests and a Chromium headless smoke test;
9. builds portable ZIP and per-user installer;
10. creates SHA-256 checksums;
11. publishes a stable GitHub Release on `main` when that version does not already exist;
12. mirrors the immutable release bundle to GitHub Container Registry.

## Trust boundaries

Ghosium code is trusted distribution code. Web content runs inside Chromium's upstream process/sandbox model. Browser extensions have the permissions shown by Chromium. Network services are external trust boundaries.

The Ghosium new-tab page intentionally has no remote runtime dependencies.

## Why C++

Chromium's native desktop browser code and Views UI are primarily C++. Using C++ for the Ghosium launcher keeps the custom executable close to the upstream platform and avoids adding another application runtime.

## Full-source fork path

A future fully rebranded browser can apply Ghosium patches directly to a pinned Chromium source checkout and build Chromium's `chrome`/`mini_installer` targets. That requires a high-storage build machine; the lightweight release pipeline remains useful for fast revision validation and distribution testing.
