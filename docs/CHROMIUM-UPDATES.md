# Chromium Update Policy

Ghosium's web engine is upstream Chromium. Keeping that base current is a security requirement, not only a feature update.

## Source of Chromium binaries

The standard Windows distribution pipeline downloads from the official Chromium infrastructure bucket:

```text
https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/
```

`CHROMIUM_REVISION` is the single pinned snapshot position for production builds.

## Development resolution

A development branch may temporarily set:

```text
latest
```

The CI workflow then reads the official `LAST_CHANGE` object and reports the resolved numeric revision in `BUILD-INFO.json`.

That numeric value must be committed to `CHROMIUM_REVISION` before a production release is merged.

## Update checklist

For each revision update:

- confirm the archive exists in the official bucket
- record the archive SHA-256
- record Chromium file product version
- record the Chromium source revision from `REVISIONS` metadata when available
- run launcher self-test
- run Chromium headless startup/render smoke test
- open normal settings, downloads, history, extensions and password manager during manual release validation
- verify the Ghosium new-tab component loads
- verify tracker rules do not cause obvious navigation breakage
- verify profile persistence across restarts
- verify setup install/uninstall and portable extraction

## Security cadence

Chromium releases security fixes frequently. Ghosium should prefer small, frequent Chromium revision updates over large delayed jumps.

When an upstream stable security issue is actively exploited, prioritize moving to a Chromium revision containing the fix and publishing a new Ghosium stable patch release.

## Full-source builds

When the distribution model needs a Chromium-native branding/UI patch, pin the corresponding Chromium source tag or commit and use the full-source procedure in `BUILDING.md`. Do not apply unreviewed binary patches to the packaged Chromium executable or DLLs.
