# Ghosium Stable Release Procedure

## Release policy

Ghosium publishes normal stable GitHub Releases only. The workflow does not use the pre-release flag.

## Public release assets

Exactly two explicit assets are attached:

- `Ghosium-Browser-Setup.exe`
- `Ghosium-Browser-Portable.exe`

GitHub automatically exposes the matching source-code archives for the release tag. Search/Store shared-hosting source is included there rather than attached as separate web ZIP assets.

## Required green checks

Before publication:

- Ghosium Search PHP/JSON tests pass
- Ghosium Store PHP/JSON tests pass
- Ghosium-controlled UI contains only Ghosium product links
- desktop executable source validation passes
- Ghosium launcher builds with hardening flags
- launcher self-test passes
- upstream engine starts after Ghosium packaging/rename
- Setup EXE builds
- Portable EXE builds

## Versioning

`VERSION`, bundled component versions and release tag must match.

Production uses a pinned numeric `ENGINE_REVISION`.

## GitHub Package

After the stable Release succeeds, the same verified Setup/Portable executables are mirrored into the versioned Ghosium GitHub Package/OCI bundle and tagged with both the release version and `latest`.

## Signing

The current workflow does not claim Authenticode signing unless a valid Brendigo code-signing certificate is explicitly configured. Never describe an unsigned build as signed.
