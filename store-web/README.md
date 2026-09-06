# Ghosium Store shared-hosting source

`store-web/` is the source for `https://store.ghosium.com/`.

## Requirements

- PHP 8.1+
- Apache or LiteSpeed with `.htaccess`
- HTTPS

No database is required. The extension catalog is stored in `storage/data/extensions.json`; direct HTTP access to `storage/` is denied.

## Deploy

1. Upload the contents of `store-web/` to the document root for `store.ghosium.com`.
2. Enable HTTPS.
3. Confirm the home page loads and `/api/catalog.php` returns JSON.
4. Keep all extension metadata and packages on Ghosium-controlled infrastructure.

## Distribution model

The initial store is a curated catalog. Built-in Ghosium components appear as `built_in`. Future third-party packages can be added only after review. Public one-click off-store extension installation is intentionally not forced through enterprise-policy workarounds; deeper browser-engine integration is required before that feature is safe for a public consumer browser.

## Privacy

The store has no analytics, remote fonts, third-party assets, advertising SDKs or user accounts. Its CSP permits only same-origin application resources. Hosting-provider access logs remain outside the application and should be configured according to the Ghosium privacy policy.
