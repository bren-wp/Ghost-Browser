# Ghosium Search Architecture

## Browser integration

`search-provider/manifest.json` defines Ghosium Search as the default Chromium search provider:

```text
https://search.ghosium.com/?q={searchTerms}
```

Suggestions use:

```text
https://search.ghosium.com/api/suggest.php?q={searchTerms}
```

The new-tab form uses the same Ghosium endpoint. No third-party search URL is hardcoded into these browser entry points.

## Local index mode

Default `search-web/storage/data/config.json` leaves the remote provider disabled. Queries are ranked against `index.json`, which can be rebuilt from `seeds.json` using the CLI crawler.

This is the genuinely first-party mode: Ghosium owns the search UI, HTTP endpoint, crawler seed set, JSON index and ranker.

## Optional provider mode

For broader coverage before Ghosium operates a large distributed crawler, an administrator can configure a generic HTTPS JSON provider. It must return `results[]` with `title`, `url` and `description`. No vendor implementation is hardcoded.

The browser sees only `search.ghosium.com`; the provider API key stays on the search server. Privacy documentation must still disclose that queries are forwarded when provider mode is enabled.

## Scale limitation

A complete public-web index requires distributed crawling, deduplication, spam controls, language analysis, large persistent indexes and continuous recrawling. A shared-hosting JSON implementation is intentionally suitable for a curated/early index, not a false claim of internet-scale coverage.
