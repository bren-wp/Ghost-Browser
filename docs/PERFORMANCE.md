# Ghosium Performance

## Default behavior

Ghosium uses normal browser-engine resource behavior on systems with more than 8 GiB RAM.

## Automatic Low Memory mode

If Windows reports 8 GiB RAM or less, the launcher automatically applies:

- renderer process limit: 6
- disk cache budget: 128 MiB

This targets older or lower-memory PCs without disabling the sandbox, certificate validation or core process isolation.

## Manual overrides

- `--ghosium-low-memory` forces the constrained profile.
- `--ghosium-balanced` forces normal engine resource behavior.

Caller-provided switches cannot override Ghosium-owned profile, bundled-component or language settings.

## Installer/Portable optimization

Setup and Portable use zlib compression rather than a very large solid-compression dictionary. The trade-off is a somewhat larger EXE in exchange for faster packaging and lower decompression memory pressure on weaker PCs.

Portable mode extracts the runtime temporarily, waits for the browser to close and removes temporary runtime files afterward. User profile data remains persistent beside the Portable EXE.

## Security rule

Performance changes must not disable sandboxing, TLS/certificate validation, process isolation or other fundamental browser security boundaries.
