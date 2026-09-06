# Ghosium Privacy Model

## What Ghosium itself does not collect

The Ghosium desktop launcher does not implement application analytics, an advertising identifier, behavioral profiling, cloud profile sync or a Ghosium crash-upload backend. The browser profile is stored locally under `%LOCALAPPDATA%\Ghosium Browser\User Data`.

The bundled launcher disables Chromium browser sync, crash reporting, background browser mode, Domain Reliability reporting and hyperlink-auditing pings for the launched runtime.

## Ghosium Search

Browser search goes to `https://search.ghosium.com/` rather than a hardcoded third-party search page. The included shared-hosting service does not set tracking cookies and does not keep an application log of raw search queries.

In local-index mode a query is evaluated against `storage/data/index.json` on the Ghosium Search server. The optional provider mode sends the query from the server to the configured HTTPS provider; if provider mode is enabled, that provider necessarily receives the query. Provider API keys remain server-side.

Cache entries use a SHA-256 key derived from the normalized query rather than storing the raw query as the cache key. Rate limiting stores an HMAC identifier for the client network address and time window, not the raw IP address. The hosting company/web server may still maintain infrastructure access logs outside the PHP application.

## Websites still receive network traffic

Privacy hardening cannot make a website you intentionally visit unable to receive your connection. Destination sites can receive the IP address exposed by your network/VPN, browser headers, requests, cookies and other browser-visible signals. Ghosium's declarative rules reduce selected third-party tracking and common tracking parameters but do not promise universal anti-fingerprinting.

Visiting a large platform directly can allow that platform to observe the direct visit. Ghosium therefore cannot truthfully guarantee that any named internet company can never track a user under every browsing scenario.

## Search and navigation separation

The browser uses Ghosium Search for non-URL omnibox terms through the bundled search-provider component. Direct URLs are loaded directly by Chromium and are not proxied through Ghosium Search.

## Sensitive permissions

Camera, microphone, location, notifications and other sensitive web capabilities remain controlled by Chromium's normal site-permission UI. Ghosium does not bypass permission prompts to improve compatibility or performance.

## Security features intentionally retained

Ghosium does not disable the Chromium sandbox, certificate validation, Site Isolation or other core security boundaries merely to reduce memory usage or network traffic.
