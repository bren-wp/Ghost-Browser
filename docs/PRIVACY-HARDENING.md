# Ghosium Privacy Hardening

## Principles

Ghosium privacy defaults aim to reduce unnecessary product/background network traffic without weakening fundamental browser security.

## Launcher defaults

The native launcher disables:

- browser sync
- crash reporting
- background browser mode
- background networking subsystems
- Domain Reliability reporting
- hyperlink-auditing pings
- first-run/default-browser nags

## Declarative request protection

The bundled Ghosium Privacy component blocks selected well-known third-party advertising/analytics endpoints and strips common campaign/click identifiers from top-level navigations.

The component is declarative and script-free, reducing persistent extension runtime overhead.

## What is intentionally not disabled

- sandboxing
- certificate validation
- process isolation
- ordinary user-requested HTTPS traffic
- user-selected extensions

## Product links

Ghosium-controlled UI links point only to Ghosium-owned domains. Search results and sites explicitly entered by the user remain ordinary web content and can lead anywhere on the public web.

## Update discipline

Privacy hardening never replaces engine security updates. `ENGINE_REVISION` must be refreshed and fully smoke-tested whenever a newer supported engine baseline is adopted.
