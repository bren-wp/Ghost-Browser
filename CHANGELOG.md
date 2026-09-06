# Changelog

## 0.6.0

- replaced the former embedded-browser application architecture with direct upstream Chromium distribution
- removed WebView2/Tauri/Rust/TypeScript browser runtime layers
- standardized Ghosium-owned desktop executable code on C++20
- added hardened command-line filtering and Windows image-load mitigations
- added automatic Low Memory mode for systems with 8 GiB RAM or less
- retained normal Balanced mode and Chromium security isolation
- added script-free Ghosium new-tab design with no vertical scrolling
- changed all bundled search entry points to Ghosium Search
- added single-purpose Manifest V3 Ghosium Search provider override
- retained declarative Ghosium Privacy filtering and tracking-parameter cleanup
- added complete `search.ghosium.com` PHP shared-hosting implementation with JSON storage and no database
- added local JSON crawler/index, local ranker, suggestion endpoint, optional generic server-side provider and privacy-aware cache/rate limiting
- added PHP/JSON search-service CI smoke tests
- fixed deterministic Chromium/C++ smoke testing
- fixed NSIS staging-path handling with absolute build definitions
- added shared-hosting Search ZIP to stable release assets and checksums
- updated stable Release and GitHub Packages publication workflow
- expanded architecture, privacy, performance, search, deployment and release documentation
