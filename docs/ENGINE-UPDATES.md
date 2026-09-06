# Ghosium Engine Updates

## Pinning

Production builds use a numeric value in `ENGINE_REVISION`. `main` must never publish from an unpinned `latest` value.

## Update process

1. Resolve a newer official upstream Windows engine revision.
2. Create a development branch and update `ENGINE_REVISION`.
3. Run the complete Ghosium CI pipeline.
4. Confirm native launcher compilation, renamed engine startup, Search/Store web tests, Setup EXE and Portable EXE.
5. Review upstream security/release notes as applicable.
6. Merge only after CI passes.
7. Publish the next normal stable Ghosium release.

## Provenance

CI records upstream archive hash, source revision and engine version internally during the build. Required third-party license material is bundled inside the installed application even though public GitHub Release assets are intentionally limited to the two Ghosium EXE files.

## Branding

User-facing Ghosium documentation does not expose upstream product branding. Required legal attribution remains in `THIRD_PARTY_NOTICES.md` and installed upstream license files.
