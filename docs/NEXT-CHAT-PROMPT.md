# Ghosium Browser v0.7.0 handoff prompt

This file is intentionally not user-facing product UI. It summarizes the next engineering phase for a future chat/session.

Continue only in `bren-wp/Ghosium-Browser`. Start from the latest stable `main` after v0.7.0. Preserve Ghosium branding, C++20 desktop launcher, Ghosium Search, Ghosium Store, 30-language installer, Low Memory mode, stable-only releases and Release assets limited to Setup.exe + Portable.exe.

Primary next goal: move from distribution-layer branding to a full-source Ghosium engine build so internal browser strings, About/help pages, built-in extension-store routing, application icons/resources, Windows file metadata and remaining upstream product links can be replaced with Ghosium-owned equivalents while preserving all legally required third-party license/copyright notices.

Do not weaken sandboxing, certificate validation, process isolation or extension security. Do not use enterprise-policy hacks for a public consumer extension store. Keep public Ghosium product links on ghosium.com, search.ghosium.com and store.ghosium.com. Keep Brendigo as publisher/author. Continue improving security, stability, weak-PC performance, accessibility, translations, installer UX, reproducible builds and supply-chain provenance.
