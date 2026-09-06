<?php
declare(strict_types=1);

const GHOSIUM_STORE_SCHEMA_VERSION = 1;
const GHOSIUM_STORE_MAX_DATA_BYTES = 1048576;
const GHOSIUM_STORE_MAX_PACKAGE_BYTES = 134217728;

function store_root_path(): string
{
    return dirname(__DIR__);
}

function store_data_path(string $name): string
{
    return store_root_path() . '/storage/data/' . $name;
}

function store_read_json(string $path): array
{
    if (!is_file($path) || !is_readable($path)) {
        throw new RuntimeException('Required store data is unavailable.');
    }

    $size = filesize($path);
    if ($size === false || $size < 2 || $size > GHOSIUM_STORE_MAX_DATA_BYTES) {
        throw new RuntimeException('Store data size is invalid.');
    }

    $raw = file_get_contents($path);
    if ($raw === false) {
        throw new RuntimeException('Unable to read store data.');
    }

    try {
        $decoded = json_decode($raw, true, 64, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        throw new RuntimeException('Store data is not valid JSON.', 0, $exception);
    }

    if (!is_array($decoded)) {
        throw new RuntimeException('Store data root must be an object.');
    }

    return $decoded;
}

function store_valid_id(string $id): bool
{
    return preg_match('/\A[a-z0-9](?:[a-z0-9._-]{0,62}[a-z0-9])?\z/D', $id) === 1;
}

function store_valid_version(string $version): bool
{
    return preg_match('/\A(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?\z/D', $version) === 1;
}

function store_valid_https_url(string $url, ?string $requiredHost = null): bool
{
    if (strlen($url) > 2048 || filter_var($url, FILTER_VALIDATE_URL) === false) {
        return false;
    }

    $parts = parse_url($url);
    if (!is_array($parts) || strtolower((string)($parts['scheme'] ?? '')) !== 'https') {
        return false;
    }

    $host = strtolower((string)($parts['host'] ?? ''));
    if ($host === '' || ($requiredHost !== null && $host !== strtolower($requiredHost))) {
        return false;
    }

    if (isset($parts['user']) || isset($parts['pass'])) {
        return false;
    }

    return true;
}

function store_valid_timestamp(string $value): bool
{
    if ($value === '' || strlen($value) > 40) {
        return false;
    }

    try {
        new DateTimeImmutable($value);
        return true;
    } catch (Exception) {
        return false;
    }
}

function store_require_string_list(mixed $value, string $field): array
{
    if (!is_array($value) || !array_is_list($value)) {
        throw new RuntimeException($field . ' must be a JSON array.');
    }

    $result = [];
    foreach ($value as $item) {
        if (!is_string($item) || $item === '' || strlen($item) > 256 || preg_match('/[\x00-\x1F\x7F]/', $item) === 1) {
            throw new RuntimeException($field . ' contains an invalid value.');
        }
        if (isset($result[$item])) {
            throw new RuntimeException($field . ' contains a duplicate value.');
        }
        $result[$item] = true;
    }

    return array_keys($result);
}

function store_permissions_digest(array $extension): string
{
    $permissions = store_require_string_list($extension['permissions'] ?? null, 'permissions');
    $hostPermissions = store_require_string_list($extension['hostPermissions'] ?? null, 'hostPermissions');
    sort($permissions, SORT_STRING);
    sort($hostPermissions, SORT_STRING);

    return hash('sha256', json_encode([
        'permissions' => $permissions,
        'hostPermissions' => $hostPermissions,
    ], JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));
}

function store_load_trusted_keys(): array
{
    $data = store_read_json(store_data_path('trusted-keys.json'));
    if (($data['schemaVersion'] ?? null) !== GHOSIUM_STORE_SCHEMA_VERSION) {
        throw new RuntimeException('Unsupported trusted-key schema.');
    }
    if (!store_valid_timestamp((string)($data['updatedAt'] ?? ''))) {
        throw new RuntimeException('Trusted-key updatedAt is invalid.');
    }

    $keys = $data['keys'] ?? null;
    if (!is_array($keys) || !array_is_list($keys)) {
        throw new RuntimeException('Trusted keys must be a JSON array.');
    }

    $seen = [];
    foreach ($keys as $key) {
        if (!is_array($key)) {
            throw new RuntimeException('Trusted-key entry must be an object.');
        }

        $keyId = (string)($key['keyId'] ?? '');
        if (preg_match('/\A[a-z0-9][a-z0-9._-]{2,63}\z/D', $keyId) !== 1 || isset($seen[$keyId])) {
            throw new RuntimeException('Trusted key id is invalid or duplicated.');
        }
        $seen[$keyId] = true;

        if (($key['algorithm'] ?? null) !== 'ed25519') {
            throw new RuntimeException('Ghosium Store trust anchors must use Ed25519.');
        }

        $publicKey = base64_decode((string)($key['publicKey'] ?? ''), true);
        if ($publicKey === false || strlen($publicKey) !== SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES) {
            throw new RuntimeException('Trusted Ed25519 public key is invalid.');
        }

        $status = (string)($key['status'] ?? '');
        if (!in_array($status, ['active', 'revoked'], true)) {
            throw new RuntimeException('Trusted key status is invalid.');
        }
        if (!store_valid_timestamp((string)($key['createdAt'] ?? ''))) {
            throw new RuntimeException('Trusted key createdAt is invalid.');
        }

        $revokedAt = $key['revokedAt'] ?? null;
        if (($status === 'active' && $revokedAt !== null) || ($status === 'revoked' && (!is_string($revokedAt) || !store_valid_timestamp($revokedAt)))) {
            throw new RuntimeException('Trusted key revocation metadata is invalid.');
        }
    }

    return $data;
}

function store_find_trusted_key(array $trustedKeys, string $keyId): ?array
{
    foreach ($trustedKeys['keys'] as $key) {
        if (($key['keyId'] ?? null) === $keyId) {
            return $key;
        }
    }
    return null;
}

function store_package_file(string $packagePath): string
{
    return store_root_path() . '/' . $packagePath;
}

function store_validate_signed_distribution(array $extension, array $trustedKeys, bool $deepVerify): void
{
    $distribution = $extension['distribution'] ?? null;
    if (!is_array($distribution) || ($distribution['type'] ?? null) !== 'signed_package') {
        throw new RuntimeException('Approved extension must use signed_package distribution.');
    }

    $packagePath = (string)($distribution['packagePath'] ?? '');
    if (
        $packagePath === '' ||
        strlen($packagePath) > 180 ||
        !str_starts_with($packagePath, 'packages/') ||
        str_contains($packagePath, '..') ||
        str_contains($packagePath, '\\') ||
        preg_match('/\Apackages\/[a-z0-9][a-z0-9._\/-]*\.crx\z/D', $packagePath) !== 1
    ) {
        throw new RuntimeException('Approved extension has an invalid packagePath.');
    }

    $downloadUrl = (string)($distribution['downloadUrl'] ?? '');
    if (!store_valid_https_url($downloadUrl, 'store.ghosium.com')) {
        throw new RuntimeException('Approved extension downloadUrl must use store.ghosium.com HTTPS.');
    }
    $urlParts = parse_url($downloadUrl);
    if (
        !is_array($urlParts) ||
        (string)($urlParts['path'] ?? '') !== '/' . $packagePath ||
        isset($urlParts['query']) ||
        isset($urlParts['fragment'])
    ) {
        throw new RuntimeException('Approved extension downloadUrl must exactly match packagePath without query or fragment.');
    }

    $sha256 = (string)($distribution['sha256'] ?? '');
    if (preg_match('/\A[a-f0-9]{64}\z/D', $sha256) !== 1) {
        throw new RuntimeException('Approved extension must provide a lowercase SHA-256 digest.');
    }

    if (($distribution['signatureAlgorithm'] ?? null) !== 'ed25519') {
        throw new RuntimeException('Approved extension must use Ed25519 signature metadata.');
    }

    $keyId = (string)($distribution['keyId'] ?? '');
    if (preg_match('/\A[a-z0-9][a-z0-9._-]{2,63}\z/D', $keyId) !== 1) {
        throw new RuntimeException('Approved extension has an invalid keyId.');
    }
    $trustedKey = store_find_trusted_key($trustedKeys, $keyId);
    if ($trustedKey === null || ($trustedKey['status'] ?? null) !== 'active') {
        throw new RuntimeException('Approved extension does not use an active trusted signing key.');
    }

    $signature = (string)($distribution['signature'] ?? '');
    $signatureBytes = base64_decode($signature, true);
    if ($signatureBytes === false || strlen($signatureBytes) !== SODIUM_CRYPTO_SIGN_BYTES) {
        throw new RuntimeException('Approved extension must provide a 64-byte Ed25519 signature.');
    }

    $review = $extension['review'] ?? null;
    if (!is_array($review)) {
        throw new RuntimeException('Approved extension is missing review metadata.');
    }

    $permissionReview = $review['permissionReview'] ?? null;
    if (
        !is_array($permissionReview) ||
        ($permissionReview['status'] ?? null) !== 'approved' ||
        !store_valid_timestamp((string)($permissionReview['reviewedAt'] ?? '')) ||
        trim((string)($permissionReview['reviewer'] ?? '')) === '' ||
        (string)($permissionReview['permissionsSha256'] ?? '') !== store_permissions_digest($extension)
    ) {
        throw new RuntimeException('Approved extension requires an approved permission review bound to its permission set.');
    }

    $malwareScan = $review['malwareScan'] ?? null;
    if (
        !is_array($malwareScan) ||
        ($malwareScan['status'] ?? null) !== 'passed' ||
        !store_valid_timestamp((string)($malwareScan['scannedAt'] ?? '')) ||
        trim((string)($malwareScan['scanner'] ?? '')) === '' ||
        (string)($malwareScan['packageSha256'] ?? '') !== $sha256
    ) {
        throw new RuntimeException('Approved extension requires a passed malware scan bound to the package SHA-256.');
    }

    $packageFile = store_package_file($packagePath);
    if (!is_file($packageFile) || !is_readable($packageFile)) {
        throw new RuntimeException('Approved extension package is unavailable.');
    }
    $packageBytes = filesize($packageFile);
    if ($packageBytes === false || $packageBytes < 1 || $packageBytes > GHOSIUM_STORE_MAX_PACKAGE_BYTES) {
        throw new RuntimeException('Approved extension package size is invalid.');
    }

    if (!$deepVerify) {
        return;
    }

    if (!function_exists('sodium_crypto_sign_verify_detached')) {
        throw new RuntimeException('PHP sodium extension is required for deep package verification.');
    }

    $actualSha256 = hash_file('sha256', $packageFile);
    if (!is_string($actualSha256) || !hash_equals($sha256, strtolower($actualSha256))) {
        throw new RuntimeException('Approved extension package SHA-256 does not match catalog metadata.');
    }

    $package = file_get_contents($packageFile);
    if ($package === false) {
        throw new RuntimeException('Unable to read approved extension package for signature verification.');
    }
    $publicKey = base64_decode((string)$trustedKey['publicKey'], true);
    if ($publicKey === false || !sodium_crypto_sign_verify_detached($signatureBytes, $package, $publicKey)) {
        throw new RuntimeException('Approved extension package Ed25519 signature verification failed.');
    }
}

function store_validate_extension(array $extension, array $trustedKeys, bool $deepVerify): void
{
    $id = (string)($extension['id'] ?? '');
    if (!store_valid_id($id)) {
        throw new RuntimeException('Extension id is invalid.');
    }

    $name = trim((string)($extension['name'] ?? ''));
    $description = trim((string)($extension['description'] ?? ''));
    $publisher = trim((string)($extension['publisher'] ?? ''));
    if ($name === '' || strlen($name) > 120 || $description === '' || strlen($description) > 1200 || $publisher === '' || strlen($publisher) > 120) {
        throw new RuntimeException('Extension display metadata is invalid.');
    }

    $version = (string)($extension['version'] ?? '');
    if (!store_valid_version($version)) {
        throw new RuntimeException('Extension version is invalid.');
    }

    if (($extension['manifestVersion'] ?? null) !== 3) {
        throw new RuntimeException('Ghosium Store accepts Manifest V3 metadata only.');
    }

    $status = (string)($extension['status'] ?? '');
    if (!in_array($status, ['built_in', 'approved'], true)) {
        throw new RuntimeException('Extension status is invalid.');
    }

    if (!store_valid_https_url((string)($extension['homepage'] ?? ''))) {
        throw new RuntimeException('Extension homepage must be HTTPS.');
    }

    store_require_string_list($extension['permissions'] ?? null, 'permissions');
    store_require_string_list($extension['hostPermissions'] ?? null, 'hostPermissions');

    $distribution = $extension['distribution'] ?? null;
    if (!is_array($distribution)) {
        throw new RuntimeException('Extension distribution metadata is missing.');
    }

    if ($status === 'built_in') {
        if (($distribution['type'] ?? null) !== 'bundled' || !array_key_exists('package', $distribution) || $distribution['package'] !== null) {
            throw new RuntimeException('Built-in extensions must use bundled distribution without a downloadable package.');
        }
        return;
    }

    store_validate_signed_distribution($extension, $trustedKeys, $deepVerify);
}

function store_load_catalog(bool $deepVerify = false): array
{
    $catalog = store_read_json(store_data_path('extensions.json'));
    if (($catalog['schemaVersion'] ?? null) !== GHOSIUM_STORE_SCHEMA_VERSION) {
        throw new RuntimeException('Unsupported Ghosium Store catalog schema.');
    }
    if (!store_valid_timestamp((string)($catalog['updatedAt'] ?? ''))) {
        throw new RuntimeException('Catalog updatedAt is invalid.');
    }

    $extensions = $catalog['extensions'] ?? null;
    if (!is_array($extensions) || !array_is_list($extensions)) {
        throw new RuntimeException('Catalog extensions must be a JSON array.');
    }

    $trustedKeys = store_load_trusted_keys();
    $ids = [];
    foreach ($extensions as $extension) {
        if (!is_array($extension)) {
            throw new RuntimeException('Catalog extension entry must be an object.');
        }
        store_validate_extension($extension, $trustedKeys, $deepVerify);
        $id = (string)$extension['id'];
        if (isset($ids[$id])) {
            throw new RuntimeException('Catalog contains duplicate extension ids.');
        }
        $ids[$id] = true;
    }

    return $catalog;
}

function store_load_revocations(): array
{
    $data = store_read_json(store_data_path('revocations.json'));
    if (($data['schemaVersion'] ?? null) !== GHOSIUM_STORE_SCHEMA_VERSION) {
        throw new RuntimeException('Unsupported revocation schema.');
    }
    if (!store_valid_timestamp((string)($data['updatedAt'] ?? ''))) {
        throw new RuntimeException('Revocation updatedAt is invalid.');
    }

    $revocations = $data['revocations'] ?? null;
    if (!is_array($revocations) || !array_is_list($revocations)) {
        throw new RuntimeException('revocations must be a JSON array.');
    }

    $keys = [];
    foreach ($revocations as $entry) {
        if (!is_array($entry)) {
            throw new RuntimeException('Revocation entry must be an object.');
        }
        $id = (string)($entry['id'] ?? '');
        $version = $entry['version'] ?? null;
        if (!store_valid_id($id) || !is_bool($entry['allVersions'] ?? null) || !store_valid_timestamp((string)($entry['revokedAt'] ?? ''))) {
            throw new RuntimeException('Revocation metadata is invalid.');
        }
        if (($entry['allVersions'] === false) && (!is_string($version) || !store_valid_version($version))) {
            throw new RuntimeException('Version-scoped revocation requires a valid version.');
        }
        if (($entry['allVersions'] === true) && $version !== null) {
            throw new RuntimeException('All-version revocation must use a null version.');
        }
        $reason = trim((string)($entry['reason'] ?? ''));
        if ($reason === '' || strlen($reason) > 300) {
            throw new RuntimeException('Revocation reason is invalid.');
        }
        $key = $id . '|' . ($entry['allVersions'] ? '*' : (string)$version);
        if (isset($keys[$key])) {
            throw new RuntimeException('Duplicate revocation entry.');
        }
        $keys[$key] = true;
    }

    return $data;
}

function store_find_extension(array $catalog, string $id): ?array
{
    foreach ($catalog['extensions'] as $extension) {
        if (($extension['id'] ?? null) === $id) {
            return $extension;
        }
    }
    return null;
}

function store_revocation_for(array $revocations, string $id, string $version): ?array
{
    foreach ($revocations['revocations'] as $entry) {
        if (($entry['id'] ?? null) !== $id) {
            continue;
        }
        if (($entry['allVersions'] ?? false) === true || ($entry['version'] ?? null) === $version) {
            return $entry;
        }
    }
    return null;
}

function store_public_catalog(array $catalog, array $revocations): array
{
    $extensions = [];
    foreach ($catalog['extensions'] as $extension) {
        $copy = $extension;
        $revocation = store_revocation_for($revocations, (string)$extension['id'], (string)$extension['version']);
        $copy['revoked'] = $revocation !== null;
        if ($revocation !== null) {
            unset($copy['distribution']);
        }
        $extensions[] = $copy;
    }

    return [
        'schemaVersion' => GHOSIUM_STORE_SCHEMA_VERSION,
        'updatedAt' => $catalog['updatedAt'],
        'extensions' => $extensions,
    ];
}

function store_json_response(array $payload, int $status = 200, string $cacheControl = 'public, max-age=300'): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=UTF-8');
    header('Cache-Control: ' . $cacheControl);
    header('Referrer-Policy: no-referrer');
    header('X-Content-Type-Options: nosniff');
    header('X-Robots-Tag: noindex, nofollow');
    header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}

function store_public_error(): never
{
    store_json_response(['error' => 'store_unavailable'], 503, 'no-store');
}
