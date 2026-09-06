<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/store.php';

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    header('Allow: GET');
    store_json_response(['error' => 'method_not_allowed'], 405, 'no-store');
}

$id = (string)($_GET['id'] ?? '');
$currentVersion = (string)($_GET['version'] ?? '');
if (!store_valid_id($id) || !store_valid_version($currentVersion)) {
    store_json_response(['error' => 'invalid_request'], 400, 'no-store');
}

try {
    $catalog = store_load_catalog(false);
    $revocations = store_load_revocations();
    $extension = store_find_extension($catalog, $id);
    if ($extension === null) {
        store_json_response(['error' => 'not_found'], 404, 'no-store');
    }

    $installedRevocation = store_revocation_for($revocations, $id, $currentVersion);
    if ($installedRevocation !== null) {
        store_json_response([
            'id' => $id,
            'version' => $currentVersion,
            'revoked' => true,
            'revokedAt' => $installedRevocation['revokedAt'],
            'reason' => $installedRevocation['reason'],
        ], 410, 'no-store');
    }

    $latestVersion = (string)$extension['version'];
    $latestRevocation = store_revocation_for($revocations, $id, $latestVersion);
    if ($latestRevocation !== null) {
        store_json_response([
            'id' => $id,
            'updateAvailable' => false,
            'latestVersion' => $latestVersion,
            'latestVersionRevoked' => true,
        ], 200, 'public, max-age=60');
    }

    if (($extension['status'] ?? null) === 'built_in') {
        store_json_response([
            'id' => $id,
            'updateAvailable' => false,
            'latestVersion' => $latestVersion,
            'distribution' => 'bundled',
        ], 200, 'public, max-age=300');
    }

    if (version_compare($currentVersion, $latestVersion, '>=')) {
        store_json_response([
            'id' => $id,
            'updateAvailable' => false,
            'latestVersion' => $latestVersion,
        ], 200, 'public, max-age=300');
    }

    $distribution = $extension['distribution'];
    $permissionReview = $extension['review']['permissionReview'];
    store_json_response([
        'id' => $id,
        'updateAvailable' => true,
        'version' => $latestVersion,
        'manifestVersion' => $extension['manifestVersion'],
        'downloadUrl' => $distribution['downloadUrl'],
        'sha256' => $distribution['sha256'],
        'signatureAlgorithm' => $distribution['signatureAlgorithm'],
        'keyId' => $distribution['keyId'],
        'signature' => $distribution['signature'],
        'permissionsSha256' => $permissionReview['permissionsSha256'],
    ], 200, 'public, max-age=60');
} catch (Throwable) {
    store_public_error();
}
