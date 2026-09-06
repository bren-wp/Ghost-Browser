# Changelog

All notable Ghosium Browser distribution changes are documented here.

## 0.6.0 — Chromium-native migration

- replaced the custom browser application runtime with the upstream open-source Chromium Windows browser distribution
- reduced Ghosium-authored executable code to a native C++ launcher
- retained the established dark aurora/neon/violet Ghosium visual identity in a local new-tab page
- added a Manifest V3 declarative privacy component with no custom JavaScript runtime
- added conservative third-party tracker blocking and common tracking-parameter removal
- disabled browser sync, crash reporting, background mode and hyperlink auditing pings through supported Chromium switches
- moved profile data to a dedicated `%LOCALAPPDATA%\Ghosium Browser\User Data` root
- inherited Chromium-native tabs, settings, bookmarks, history, downloads, password manager, site permissions, extensions and DevTools instead of maintaining parallel implementations
- added pinned Chromium revision metadata and upstream archive hashing
- replaced the old release pipeline with Chromium distribution validation, C++ hardening, headless smoke tests, stable GitHub Releases and GitHub Container Registry package publication
- added complete architecture, build, privacy, security, contribution, release and Chromium-update documentation
- added BSD 3-Clause licensing for Ghosium-authored source and third-party attribution documentation

## 0.5.1

Historical release from the previous architecture. Users should upgrade to the current stable Chromium-native release once available.
