# Deploying Ghosium Search on Shared Hosting

Target: `https://search.ghosium.com/`

## Requirements

- PHP 8.1+
- cURL + DOM PHP extensions
- Apache/LiteSpeed `.htaccess`
- HTTPS
- writable `storage/data`

## Steps

1. Obtain the source code for the matching Ghosium release tag.
2. Upload the contents of `search-web/` to the Search subdomain document root.
3. Ensure `storage/data` is writable by PHP but remains blocked from direct HTTP access.
4. Open `/health.php` and confirm `status: ok`.
5. Add desired HTTPS seeds to `storage/data/seeds.json`.
6. Configure hosting cron to run `cron/reindex.php`.
7. Leave the optional provider disabled unless you intentionally configure your own server-side compatible JSON service.

## Privacy

Do not enable hosting analytics or query logging if you want the deployed service to match the repository privacy model. Review your hosting provider's access-log settings separately because those logs are outside the PHP application.

## Browser endpoints

Search: `https://search.ghosium.com/?q={searchTerms}`

Suggestions: `https://search.ghosium.com/api/suggest.php?q={searchTerms}`
