<?php
declare(strict_types=1);

$repoRoot = dirname(__DIR__);
require_once $repoRoot . '/store-web/lib/store.php';

function fail_store_audit(string $message): never
{
    fwrite(STDERR, $message . PHP_EOL);
    exit(1);
}

function same_string_set(array $left, array $right): bool
{
    sort($left, SORT_STRING);
    sort($right, SORT_STRING);
    return $left === $right;
}

if (!function_exists('sodium_crypto_sign_keypair')) {
    fail_store_audit('PHP sodium extension is required for Ghosium Store trust verification.');
}

try {
    $catalog = store_load_catalog(true);
    $revocations = store_load_revocations();
    $trustedKeys = store_load_trusted_keys();
} catch (Throwable $exception) {
    fail_store_audit('Store schema validation failed: ' . $exception->getMessage());
}

$privacyManifest = json_decode((string)file_get_contents($repoRoot . '/extension/manifest.json'), true, 32, JSON_THROW_ON_ERROR);
$searchManifest = json_decode((string)file_get_contents($repoRoot . '/search-provider/manifest.json'), true, 32, JSON_THROW_ON_ERROR);

$privacy = store_find_extension($catalog, 'ghosium-privacy');
$search = store_find_extension($catalog, 'ghosium-search');
if ($privacy === null || $search === null) {
    fail_store_audit('Built-in Ghosium Store catalog entries are missing.');
}

foreach ([
    [$privacy, $privacyManifest, 'Ghosium Privacy'],
    [$search, $searchManifest, 'Ghosium Search'],
] as [$entry, $manifest, $label]) {
    if (($entry['status'] ?? null) !== 'built_in' || ($entry['distribution']['type'] ?? null) !== 'bundled') {
        fail_store_audit($label . ' must remain a bundled built-in component.');
    }
    if ((string)$entry['version'] !== (string)$manifest['version']) {
        fail_store_audit($label . ' Store version does not match its manifest.');
    }
    if ((int)$entry['manifestVersion'] !== (int)$manifest['manifest_version']) {
        fail_store_audit($label . ' Store manifest version does not match its manifest.');
    }

    $manifestPermissions = array_values($manifest['permissions'] ?? []);
    $manifestHostPermissions = array_values($manifest['host_permissions'] ?? []);
    if (!same_string_set($entry['permissions'], $manifestPermissions)) {
        fail_store_audit($label . ' Store permissions do not match its manifest.');
    }
    if (!same_string_set($entry['hostPermissions'], $manifestHostPermissions)) {
        fail_store_audit($label . ' Store host permissions do not match its manifest.');
    }
}

foreach ($catalog['extensions'] as $entry) {
    $revocation = store_revocation_for($revocations, (string)$entry['id'], (string)$entry['version']);
    if (($entry['status'] ?? null) === 'approved' && $revocation !== null) {
        fwrite(STDOUT, 'Revoked approved package remains listed but update delivery is blocked: ' . $entry['id'] . PHP_EOL);
    }
}

$testPackagePath = $repoRoot . '/store-web/packages/ci-signed-test.crx';
$testPackageRelative = 'packages/ci-signed-test.crx';
$testBytes = "Ghosium Store signature self-test\n" . random_bytes(64);
if (file_put_contents($testPackagePath, $testBytes, LOCK_EX) === false) {
    fail_store_audit('Unable to create Store signature self-test package.');
}

try {
    $keypair = sodium_crypto_sign_keypair();
    $secretKey = sodium_crypto_sign_secretkey($keypair);
    $publicKey = sodium_crypto_sign_publickey($keypair);
    $keyId = 'ci-ed25519-test';
    $packageSha256 = hash('sha256', $testBytes);
    $signature = sodium_crypto_sign_detached($testBytes, $secretKey);

    $synthetic = [
        'id' => 'ci-signed-test',
        'name' => 'CI Signed Test',
        'version' => '1.0.0',
        'manifestVersion' => 3,
        'status' => 'approved',
        'description' => 'Ephemeral cryptographic Store validation package.',
        'publisher' => 'Brendigo CI',
        'homepage' => 'https://ghosium.com/security',
        'permissions' => ['storage'],
        'hostPermissions' => [],
        'distribution' => [
            'type' => 'signed_package',
            'packagePath' => $testPackageRelative,
            'downloadUrl' => 'https://store.ghosium.com/' . $testPackageRelative,
            'sha256' => $packageSha256,
            'signatureAlgorithm' => 'ed25519',
            'keyId' => $keyId,
            'signature' => base64_encode($signature),
        ],
        'review' => [
            'permissionReview' => [
                'status' => 'approved',
                'reviewedAt' => '2026-09-07T00:00:00Z',
                'reviewer' => 'Brendigo CI',
                'permissionsSha256' => '',
            ],
            'malwareScan' => [
                'status' => 'passed',
                'scannedAt' => '2026-09-07T00:00:00Z',
                'scanner' => 'Ghosium CI fixture',
                'packageSha256' => $packageSha256,
            ],
        ],
    ];
    $synthetic['review']['permissionReview']['permissionsSha256'] = store_permissions_digest($synthetic);

    $syntheticKeys = [
        'schemaVersion' => GHOSIUM_STORE_SCHEMA_VERSION,
        'updatedAt' => '2026-09-07T00:00:00Z',
        'keys' => [[
            'keyId' => $keyId,
            'algorithm' => 'ed25519',
            'publicKey' => base64_encode($publicKey),
            'status' => 'active',
            'createdAt' => '2026-09-07T00:00:00Z',
            'revokedAt' => null,
        ]],
    ];

    store_validate_extension($synthetic, $syntheticKeys, true);

    file_put_contents($testPackagePath, $testBytes . 'tampered', LOCK_EX);
    $tamperRejected = false;
    try {
        store_validate_extension($synthetic, $syntheticKeys, true);
    } catch (RuntimeException) {
        $tamperRejected = true;
    }
    if (!$tamperRejected) {
        fail_store_audit('Tampered Store package was not rejected.');
    }
} finally {
    @unlink($testPackagePath);
}

if ($trustedKeys['keys'] === []) {
    fwrite(STDOUT, "No production third-party signing keys are published yet; downloadable third-party packages therefore remain fail-closed.\n");
}

fwrite(STDOUT, "Ghosium Store schema, bundled manifests, SHA-256 and Ed25519 trust verification: OK\n");
