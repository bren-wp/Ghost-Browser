# Ghosium Search Architecture

## Browser integration

Ghosium Browser sends New Tab and default search requests to:

```text
https://search.ghosium.com/?q={searchTerms}
```

Suggestions use:

```text
https://search.ghosium.com/api/suggest.php?q={searchTerms}
```

The bundled search-provider component contains no custom JavaScript runtime.

## Shared-hosting implementation

`search-web/` is a PHP 8.1+ application using JSON storage. It provides:

- search results page
- `/api/search.php`
- `/api/suggest.php`
- `/health.php`
- local JSON index/ranker
- seed-based CLI crawler
- query cache
- privacy-preserving rate limiting
- optional server-side compatible JSON provider

## Data boundaries

The browser sends the user's search text to `search.ghosium.com` when the user initiates a search. No Ghosium account is required.

The local application does not keep a raw query log. A hosting provider may keep web-server access logs independently of the application.

## Global-index limitation

Shared hosting plus JSON is a deployment-friendly first-party search layer, not a complete web-scale index. A future global Ghosium Search requires distributed crawling, indexing, ranking and anti-abuse infrastructure.
