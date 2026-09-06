# Ghosium Store Architecture

## Public URL

`https://store.ghosium.com/`

## v0.7.0 scope

The first Ghosium Store release is a curated catalog and JSON API hosted entirely on Ghosium infrastructure.

`store-web/` provides:

- server-rendered catalog page
- `/api/catalog.php`
- JSON catalog storage
- CSP and anti-framing headers
- no database
- no analytics
- no remote fonts
- no third-party assets

## Extension installation model

The initial Store does not force public off-store one-click installation through enterprise-policy mechanisms. That would be inappropriate for a public consumer browser and can trigger security/anti-malware concerns.

Future one-click installation should be implemented only through deeper first-party engine integration, with signed packages, update manifests, publisher verification, permission review, malware scanning, revocation and update integrity.

## Catalog data

`store-web/storage/data/extensions.json` is the source of truth for visible catalog entries. `storage/` is blocked from direct HTTP access.

Recommended future fields include package hash, signature, permission summary, minimum Ghosium version, review timestamp and security status.
