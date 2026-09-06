# Stable Release Procedure

1. Select and pin a numeric `CHROMIUM_REVISION`.
2. Update `VERSION` and both bundled Manifest V3 versions.
3. Review Chromium upstream security changes.
4. Run PR CI until both `Verify Ghosium Search shared hosting` and `Build and verify Windows x64` are green.
5. Merge to `main` only after the Chromium download, source mapping, C++ compile, launcher self-test, Chromium smoke test, NSIS build and PHP search tests all pass.
6. The `main` push creates a normal GitHub Release only if the `vVERSION` tag does not already exist.
7. Release publication defaults to stable; no pre-release flag is used.
8. After the stable Release succeeds, the same verified bundle is published to `ghcr.io/bren-wp/ghosium-browser:VERSION` and `:latest`.

Release assets include Browser Setup, Browser Portable ZIP, Ghosium Search shared-hosting ZIP, SHA-256 sums and Chromium provenance/license files.

Never reuse an existing version number for different binaries.
