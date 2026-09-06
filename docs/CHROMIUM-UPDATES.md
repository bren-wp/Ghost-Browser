# Chromium Update Process

`CHROMIUM_REVISION` must contain a numeric Windows x64 Chromium snapshot revision for production `main` builds.

For each proposed update:

1. resolve a current official snapshot revision;
2. pin the numeric value in `CHROMIUM_REVISION`;
3. run PR CI;
4. confirm the downloaded `chrome.exe` product version;
5. confirm `crrev` maps the snapshot to a Chromium source Git SHA;
6. record the SHA-256 of the upstream archive;
7. run C++ launcher and Chromium headless smoke tests;
8. review upstream security/release notes before publishing;
9. increment the Ghosium version if release assets will change.

`BUILD-INFO.json`, `CHROMIUM-REVISION.txt` and `CHROMIUM-LICENSE.txt` are release evidence and should ship with every stable build.
