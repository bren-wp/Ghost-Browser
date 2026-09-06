# Contributing

## Scope

Ghosium-specific executable code should remain C++ unless there is a compelling upstream Chromium requirement. Presentation resources may use HTML, CSS, SVG and JSON.

Do not introduce an additional browser engine, embedded browser runtime, application framework or JavaScript application shell.

## Change rules

- Keep the Chromium runtime upstream and pinned.
- Prefer Chromium-native behavior over reimplementing browser features.
- Do not weaken the Chromium sandbox or disable security updates/components for cosmetic reasons.
- Do not add Ghosium analytics, advertising IDs or background telemetry.
- Do not commit API keys, OAuth secrets, signing keys or passwords.
- Privacy rules must be narrowly scoped and reviewed for site-breakage risk.
- Any change to `launcher/`, `extension/`, installer logic or release workflow must update relevant documentation.
- Ghosium version changes require a `CHANGELOG.md` entry.

## Pull requests

A pull request should explain:

1. the user-visible behavior being changed;
2. security/privacy implications;
3. how it was tested;
4. whether the Chromium revision changes;
5. whether release artifacts or package metadata change.

CI must pass before merge.

## Formatting

C++ should follow a clean Chromium-like style: small functions, explicit error handling, RAII where practical, no hidden global mutable state and no exception-dependent control flow in the launcher.

## Security-sensitive changes

For vulnerabilities, use the private security reporting path described in `SECURITY.md` rather than a public pull request containing exploit details.
