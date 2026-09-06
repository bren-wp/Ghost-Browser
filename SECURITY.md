# Security Policy

## Supported releases

Only the newest stable Ghosium Browser release is supported with security fixes. Older releases should be upgraded rather than kept as long-lived security branches.

## Chromium security baseline

Ghosium's security boundary depends heavily on the Chromium revision shipped in each release. Every release records that exact revision in `BUILD-INFO.json` and `CHROMIUM-REVISION.txt`.

When upstream Chromium publishes a relevant security update, the Ghosium Chromium revision should be refreshed, the complete release workflow rerun and a new stable Ghosium version published.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting / Security Advisory flow for this repository when available. Do not publish proof-of-concept exploit details in a public issue before a fix is available.

Useful reports include:

- affected Ghosium version
- exact Chromium revision from `BUILD-INFO.json`
- Windows version and architecture
- minimal reproduction steps
- expected versus observed behavior
- whether the issue also reproduces in upstream Chromium

## Security properties checked by CI

The release workflow verifies that:

- the legacy runtime source tree is absent
- the custom programming-language code is C++ only
- extension JSON parses successfully
- the Manifest V3 ruleset contains no duplicate rule IDs
- the C++ launcher is built with common Windows binary mitigations
- required runtime and privacy files are present
- the Chromium runtime starts successfully in a headless smoke test
- release artifacts receive SHA-256 checksums
- stable release publication never uses a pre-release flag

## Out of scope

Bugs that reproduce unchanged in the exact upstream Chromium revision should normally be reported to the Chromium project as well. Ghosium cannot safely patch arbitrary Chromium memory-safety or renderer vulnerabilities at the distribution layer; those should be fixed upstream and consumed through a new Chromium revision.
