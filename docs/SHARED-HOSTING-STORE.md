# Deploying Ghosium Store on Shared Hosting

Target: `https://store.ghosium.com/`

## Requirements

- PHP 8.1+
- Apache/LiteSpeed `.htaccess`
- HTTPS

No SQL database is required.

## Steps

1. Obtain the source code for the matching Ghosium release tag.
2. Upload the contents of `store-web/` to the Store subdomain document root.
3. Confirm the catalog page loads.
4. Confirm `/api/catalog.php` returns JSON.
5. Keep `storage/` blocked from direct HTTP access.
6. Edit `storage/data/extensions.json` only through your controlled deployment process.

## Security headers

The supplied `.htaccess` applies no-indexing and browser security headers where supported. The application CSP restricts assets to the Store origin.

## Extension publishing

The initial Store is a vetted catalog. Do not publish arbitrary packages without malware review, permission review, hash/signature metadata and a revocation/update strategy.

A future one-click installation flow should be implemented through first-party engine integration rather than consumer deployment of enterprise-policy workarounds.
