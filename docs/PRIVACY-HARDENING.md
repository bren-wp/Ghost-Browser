# Privacy Hardening Rationale

Ghosium favors controls that reduce unnecessary browser-owned data flows without weakening core web security.

## Launcher switches

- sync disabled
- crash reporting disabled
- background browser mode disabled
- Domain Reliability reporting disabled
- hyperlink auditing pings disabled
- first-run/default-browser prompts disabled for a clean standalone distribution

## Declarative filtering

`extension/rules.json` blocks selected third-party tracker/advertising requests and strips common campaign/click identifiers from top-level navigations. DeclarativeNetRequest avoids a custom background JavaScript service worker.

## Search isolation

Search terms are directed to Ghosium Search. Local-index mode keeps ranking inside the Ghosium search service. Optional provider mode is server-side and should be enabled only with a provider whose privacy/contract terms are acceptable.

## Security trade-offs rejected

The launcher filters caller attempts to disable sandboxing, web security and certificate validation. It does not disable security features just to reduce memory or network activity.
