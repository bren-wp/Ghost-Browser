# Ghosium Store shared-hosting source

`store-web/` is the source for `https://store.ghosium.com/`.

## Requirements

- PHP 8.1+
- PHP Sodium extension
- Apache or LiteSpeed with `.htaccess`
- HTTPS

No database is required. Catalog, trust anchors and revocations are JSON files under `storage/data/`. Direct HTTP access to `storage/` and `lib/` is denied.

## Deploy

1. Upload the contents of `store-web/` to the document root for `store.ghosium.com`.
2. Enable HTTPS.
3. Confirm the home page loads.
4. Confirm `/api/catalog.php`, `/api/update.php`, `/api/revocations.php` and `/api/keys.php` return valid responses.
5. Keep extension metadata, packages, review records and signing operations on Ghosium-controlled infrastructure.
6. Run `php scripts/verify-store.php` from the repository before deploying catalog/package changes.

## Trust model

Built-in Ghosium components use `status: built_in` and `distribution.type: bundled`; they do not pretend to have downloadable package signatures.

A downloadable extension can use `status: approved` only when all publication invariants validate:

- Manifest V3 metadata;
- package hosted at the exact HTTPS `store.ghosium.com/packages/...crx` URL declared by the catalog;
- package size within the Store limit;
- lowercase SHA-256 digest matching the actual package;
- Ed25519 detached signature verified with an active key from `trusted-keys.json`;
- approved permission review bound to a deterministic SHA-256 digest of permissions and host permissions;
- malware-scan record bound to the same package SHA-256;
- no matching version/all-version entry in the revocation feed for update delivery.

Deep package hashing and signature verification run in CI/deployment validation rather than on every public web request, avoiding unnecessary CPU and RAM use on shared hosting. Public API requests still fail closed when catalog/trust metadata is malformed or required package files are unavailable.

`trusted-keys.json` intentionally contains no production third-party key until a real signing key has been provisioned. With no active key, third-party downloadable packages cannot pass Store validation.

## APIs

`/api/catalog.php` returns validated public catalog metadata and marks revoked entries. `/api/update.php?id=<id>&version=<version>` returns bundled/no-update state, signed update metadata, or HTTP 410 for a revoked installed version. `/api/revocations.php` publishes the revocation feed. `/api/keys.php` publishes public signing-key metadata; a browser must not treat a network-only key list as its sole root of trust.

## Privacy

The Store has no application analytics, remote fonts, third-party page assets, advertising SDKs or user accounts. Its CSP permits only same-origin application resources. Hosting-provider access logs remain outside the application and should be configured according to the Ghosium privacy policy.
