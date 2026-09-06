# Privacy

Ghosium Browser is designed so that the Ghosium distribution itself does not require a telemetry or account backend.

## What Ghosium does not collect

Ghosium-authored components do not intentionally collect or transmit:

- browsing history
- typed URLs
- search queries
- bookmarks
- saved passwords
- cookies or site storage
- device advertising identifiers
- usage analytics
- crash telemetry
- a Ghosium user account or synchronized profile

The bundled new-tab page loads all visual assets locally. It contains no analytics scripts, pixels, remote fonts or background API calls.

## Local profile

Chromium profile data is stored under:

```text
%LOCALAPPDATA%\Ghosium Browser\User Data
```

The launcher disables Chromium browser sync, so Ghosium does not intentionally synchronize that profile to a Google account.

## Network requests you should expect

A browser cannot browse the web without making network requests. The following parties may receive data as a normal consequence of use:

- websites you choose to visit
- your DNS resolver
- your network or VPN provider
- your configured search provider
- browser extensions you install
- download servers you choose to access

The default Ghosium new-tab search form submits queries to DuckDuckGo only when you submit the form. You can instead search from Chromium's omnibox and configure its default search engine through Chromium settings.

## Chromium services

Ghosium distributes open-source Chromium without injecting private Google API credentials. Features that require restricted Google APIs may therefore be unavailable. Browser sync is explicitly disabled by the launcher.

Ghosium also starts Chromium with crash reporting and background browser mode disabled. The runtime is still upstream Chromium, so users should review Chromium's own settings and permissions for site-specific behavior.

## Tracker protection

The bundled Manifest V3 component uses only local declarative rules. It blocks a conservative list of well-known third-party advertising/analytics endpoints and removes common campaign/click-tracking query parameters from top-level HTTP(S) navigation.

The ruleset is intentionally small to reduce site breakage. It is not presented as a complete anonymity system and it does not replace DNS filtering, a VPN, Tor or careful site-permission management.

## Permissions

Camera, microphone, location, notifications and related permissions are handled by Chromium's native site-permission UI. Ghosium does not auto-grant those permissions.

## Updates

Ghosium does not install a persistent background updater. Stable releases are distributed through GitHub Releases. This means users are responsible for installing security updates promptly when a new Ghosium release is published.

## Privacy limitations

No browser can promise anonymity merely by blocking trackers. Websites can still observe IP addresses, browser capabilities and data users deliberately submit. Extensions can also broaden the browser's data access. Use extension permissions and site permissions carefully.
