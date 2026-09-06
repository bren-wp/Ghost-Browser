# Ghosium Search — shared hosting

Ovaj direktorij je samostalna PHP aplikacija za `search.ghosium.com`. Ne koristi bazu podataka: konfiguracija, indeks, cache i privatnosni rate-limit podaci nalaze se u `storage/data/*.json`.

## Zahtjevi

- PHP 8.1+
- PHP cURL i DOM ekstenzije za crawler i opcionalni provider
- Apache/LiteSpeed shared hosting s `.htaccess` podrškom
- HTTPS certifikat
- `storage/data` mora biti writable za PHP proces

## Instalacija

1. Sadržaj ovog direktorija prenesite u document root poddomene `search.ghosium.com`.
2. Provjerite da `https://search.ghosium.com/health.php` vraća `status: ok`.
3. Ostavite `provider.enabled` na `false` za potpuno lokalni JSON indeks.
4. U `storage/data/seeds.json` dodajte HTTPS domene koje želite indeksirati.
5. U hostingu postavite cron, primjerice `php /home/USER/search.ghosium.com/cron/reindex.php`.

## Lokalni engine

`cron/reindex.php` dohvaća samo seed hostove, parsira naslov/opis/linkove i sprema vlastiti indeks u `storage/data/index.json`. `index.php` i `api/search.php` rangiraju taj indeks lokalno. Nema vanjskog search providera dok ga sami ne uključite.

Shared hosting i JSON datoteke nisu infrastruktura za indeks cijelog javnog weba. Za široki web indeks trebate vlastiti distribuirani crawler/index ili kompatibilan server-side API. Ghosium podržava generički JSON provider bez hardkodiranja vendor imena.

## Opcionalni kompatibilni JSON provider

U `storage/data/config.json` postavite `provider.enabled: true`, HTTPS endpoint i server-side API key. Endpoint treba vratiti:

```json
{
  "results": [
    {"title": "Naslov", "url": "https://example.com/", "description": "Opis"}
  ]
}
```

API key se nikad ne šalje browseru. Ghosium cache ključ je SHA-256 normaliziranog upita; sirovi upit se ne sprema u cache datoteku.

## Privatnost

Aplikacija ne postavlja tracking kolačiće, ne stvara korisničke račune i ne vodi aplikacijski query log. Rate limiting sprema samo HMAC identifikator mrežnog klijenta po vremenskom prozoru, bez sirove IP adrese. Web-server/hosting provider može imati vlastite access logove izvan ove aplikacije.
