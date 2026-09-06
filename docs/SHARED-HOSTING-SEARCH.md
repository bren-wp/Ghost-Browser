# Deploy search.ghosium.com on shared hosting

## Upload

Use the release asset `Ghosium-Search-Shared-Hosting-v0.6.0.zip` or upload the repository's `search-web/` contents to the document root of `search.ghosium.com`.

Recommended requirements:

- PHP 8.1 or newer
- cURL extension
- DOM extension
- Apache or LiteSpeed with `.htaccess`
- HTTPS

Make `storage/data` writable by PHP but do not make it publicly readable. The supplied `storage/.htaccess` denies web access to stored JSON.

## Verify

Open:

```text
https://search.ghosium.com/health.php
```

Expected status is `ok`.

Then test:

```text
https://search.ghosium.com/?q=Ghosium
https://search.ghosium.com/api/search.php?q=Ghosium
https://search.ghosium.com/api/suggest.php?q=Ghosium
```

## Build the local index

Edit `storage/data/seeds.json`, then add a hosting cron command similar to:

```text
php /home/ACCOUNT/search.ghosium.com/cron/reindex.php
```

The crawler is CLI-only. Start with domains you control or are authorized to crawl.

## Optional API

Set `provider.enabled` in `storage/data/config.json` only when you have a compatible HTTPS JSON endpoint. Keep the API key inside the protected configuration file. Never embed it in the browser extension or new-tab HTML.

## Backups

Back up `storage/data/config.json`, `seeds.json` and `index.json`. Cache, runtime-secret and rate-limit JSON files can be regenerated.
