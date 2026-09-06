# Stable Release Procedure

Ghosium Browser publishes normal stable GitHub Releases only. Development branches and pull requests never create releases.

## Preconditions

- `VERSION` contains a semantic version such as `0.6.0`.
- `extension/manifest.json` has the same version.
- `CHROMIUM_REVISION` contains an exact numeric Chromium snapshot revision, not `latest`.
- `CHANGELOG.md` documents the release.
- CI passes on the exact commit intended for merge.

## CI gates

The release workflow checks:

1. repository architecture invariants;
2. absence of legacy application-runtime files;
3. C++-only custom executable source;
4. valid extension manifest/rules JSON;
5. unique declarative rule IDs;
6. version synchronization;
7. official Chromium snapshot download;
8. upstream archive SHA-256 generation;
9. C++ launcher compilation with Windows mitigations;
10. launcher self-test;
11. Chromium headless smoke test;
12. installer creation;
13. release artifact SHA-256 generation.

## Stable publication

On a successful push to `main`, the workflow checks whether tag `v<VERSION>` already exists.

If the tag does not exist, it creates a standard GitHub Release with:

- portable ZIP
- Windows setup EXE
- SHA256 checksums
- build metadata
- Chromium revision/version/source metadata
- release notes

The release command does not use a pre-release flag.

If the tag already exists, the workflow treats the release as immutable and does not replace its assets.

## GitHub Packages

After a new stable release is created, a second job publishes the same release bundle to:

```text
ghcr.io/bren-wp/ghosium-browser:<VERSION>
ghcr.io/bren-wp/ghosium-browser:latest
```

The OCI package carries repository/source/version labels so GitHub can associate it with this repository.

## Emergency Chromium security update

For an urgent Chromium security update:

1. update `CHROMIUM_REVISION` to a tested newer official revision;
2. increment the Ghosium patch version;
3. update `CHANGELOG.md`;
4. run the pull-request workflow;
5. merge only after all checks pass;
6. verify the GitHub Release and GHCR package digests.
