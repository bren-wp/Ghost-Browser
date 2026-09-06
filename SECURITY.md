# Ghosium Browser Security Policy

## Supported release

Only the newest stable Ghosium Browser release is supported with security fixes. Older releases should be upgraded.

## Security baseline

Ghosium inherits a large security surface from its pinned upstream open-source browser engine. Each release therefore pins a specific `ENGINE_REVISION`; updating that revision and rerunning the complete CI pipeline is part of Ghosium security maintenance.

Ghosium does not disable the browser sandbox, certificate validation or core process isolation in order to save memory.

## Launcher protections

The native launcher:

- is compiled with `/GS`, `/sdl`, Control Flow Guard, ASLR, NX compatibility and CET compatibility
- rejects caller switches that would disable the sandbox, web security or certificate validation
- controls its own profile path, bundled components and selected language
- applies Windows image-load mitigation policy
- disables selected background networking/reporting features
- validates required runtime files before launch

## Release verification

CI verifies:

- Ghosium-owned desktop executable source remains C++ only
- bundled browser components remain script-free
- manifests and JSON parse successfully
- Ghosium Search and Ghosium Store PHP sources pass syntax tests
- web-service smoke tests pass
- the native launcher self-test passes
- the bundled engine starts in a headless smoke test
- Setup and Portable EXEs are produced and have plausible sizes
- stable Release publication attaches only the two intended EXE assets

## Reporting

Use the repository's private vulnerability reporting / Security Advisory flow when available. Avoid publishing exploit details before a fix exists.

Useful reports include the Ghosium version, Windows version, minimal reproduction steps, expected/observed behavior and whether the issue appears specific to Ghosium-owned code.

Public security page: https://ghosium.com/security
