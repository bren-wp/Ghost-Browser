# Privacy Hardening Rationale

Ghosium privacy hardening follows a conservative principle: reduce unnecessary network behavior without disabling Chromium security mechanisms that protect users.

## Launcher switches

The launcher currently applies:

- `--disable-sync` — prevents browser-data synchronization to a Google account through Chromium sync
- `--disable-breakpad` — disables crash reporting for the launched runtime
- `--disable-background-mode` — prevents background-app mode from keeping the browser alive after the final window closes
- `--no-pings` — disables hyperlink auditing pings
- `--no-first-run` — avoids upstream first-run flow in the Ghosium distribution
- `--no-default-browser-check` — avoids repeated default-browser prompts

## What Ghosium deliberately does not disable

Ghosium does not globally disable Chromium component updates, certificate validation, process sandboxing, site isolation, TLS checks or other security-critical mechanisms merely to reduce network activity.

The project also avoids broad `--disable-features` lists copied from privacy tweak collections because upstream feature names and security interactions change over time.

## Declarative tracker protection

`extension/rules.json` uses Manifest V3 declarative networking rules rather than a JavaScript request interceptor.

The shipped list is intentionally limited to recognizable third-party advertising and analytics providers. Rules use `domainType: thirdParty` where appropriate to reduce first-party site breakage.

## Tracking parameter cleanup

Top-level HTTP(S) navigation strips common campaign/click identifiers such as `utm_*`, `gclid`, `fbclid` and similar parameters using Chromium's declarative URL transform support.

## Search

The local new-tab page does not perform search suggestions or analytics. Its form makes no request until submitted. Users can ignore that form and configure Chromium's normal omnibox search provider.

## Fingerprinting

Ghosium does not currently spoof the user agent, canvas, WebGL, screen geometry or hardware concurrency. Naive anti-fingerprinting changes can make a browser more unique or break websites. Fingerprinting defenses should be based on upstream Chromium mechanisms or carefully tested, broad anonymity sets.

## Extensions

Extensions can access substantial browser data depending on permissions. Ghosium does not silently install third-party extensions. The bundled Ghosium component is local, declarative and contains no custom JavaScript.
