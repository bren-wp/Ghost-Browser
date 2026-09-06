# Security Policy

## Supported releases

Only the newest stable Ghosium Browser release is supported with Ghosium security fixes. Older releases should be upgraded rather than maintained indefinitely.

## Chromium security baseline

The desktop security boundary depends heavily on the exact Chromium revision shipped in the release. `BUILD-INFO.json` and `CHROMIUM-REVISION.txt` record that revision, product version, upstream source SHA and archive hash.

When an upstream Chromium security update is relevant, Ghosium should pin a newer revision, run the complete release pipeline and publish a new stable version.

## Ghosium-owned security boundaries

CI verifies that the desktop executable layer remains C++ only, legacy wrapper runtimes are absent, bundled browser resources contain no custom JavaScript, the search endpoint is Ghosium Search, declarative rule IDs are unique, the launcher compiles with Windows mitigations and both launcher/Chromium smoke tests pass.

The launcher blocks command-line attempts to replace the dedicated profile/extensions or disable sandbox, web security and certificate validation.

The shared-hosting search service receives separate PHP syntax/JSON validation and live endpoint smoke tests. Protected server directories ship with `.htaccess` denial rules.

## Reporting a vulnerability

Use GitHub private vulnerability reporting / Security Advisory facilities for this repository when available. Do not publish exploit details in a public issue before a fix is ready.

Include the Ghosium version, Chromium revision, Windows version, reproduction steps and whether the issue reproduces in upstream Chromium. For `search.ghosium.com`, also identify the affected endpoint and PHP version without including API keys or private configuration values.

## Upstream issues

Vulnerabilities that reproduce unchanged in the exact upstream Chromium revision should also be reported to the Chromium project. Ghosium should consume upstream fixes rather than attempting unsafe distribution-layer workarounds for renderer/sandbox memory-safety flaws.
