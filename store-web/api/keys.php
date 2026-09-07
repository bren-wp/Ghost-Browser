<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/store.php';

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    header('Allow: GET');
    store_json_response(['error' => 'method_not_allowed'], 405, 'no-store');
}

try {
    $trustedKeys = store_load_trusted_keys();
    store_json_response($trustedKeys, 200, 'public, max-age=300');
} catch (Throwable) {
    store_public_error();
}
