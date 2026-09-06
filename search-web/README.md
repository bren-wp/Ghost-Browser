# Ghosium Search — shared hosting

This directory is the standalone PHP application for `https://search.ghosium.com/`. It does not require a database: configuration, index, cache and privacy rate-limit data use `storage/data/*.json`.

## Requirements

- PHP 8.1+
- PHP cURL and DOM extensions for the crawler/optional provider
- Apache or LiteSpeed shared hosting with `.htaccess`
- HTTPS
- `storage/data` writable by PHP

## Install

1. Upload the contents of this directory to the document root for `search.ghosium.com`.
2. Confirm `https://search.ghosium.com/health.php` returns `status: ok`.
3. Leave `provider.enabled` set to `false` for a fully local JSON index.
4. Add HTTPS seed domains to `storage/data/seeds.json`.
5. Schedule `php /home/USER/search.ghosium.com/cron/reindex.php` through hosting cron.

## Local engine

`cron/reindex.php` fetches only configured seed hosts, extracts title/description/links and writes the first-party index to `storage/data/index.json`. `index.php` and `api/search.php` rank that index locally.

A single shared-hosting account with JSON files cannot maintain a complete index of the public web. A global independent Ghosium index requires dedicated distributed crawler/index infrastructure.

## Optional server-side provider

A compatible JSON provider can be enabled in the protected configuration. Its API key stays on the server and is never embedded in Ghosium Browser.

Expected response shape:

```json
{
  "results": [
    {"title": "Ghosium", "url": "https://ghosium.com/", "description": "Ghosium result"}
  ]
}
```

## Privacy

The application does not create accounts, set tracking cookies or keep a raw application query log. Rate limiting stores an HMAC identifier per time window rather than a raw client IP address. Hosting-provider access logs can still exist outside the application.
