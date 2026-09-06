<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/store.php';

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    header('Allow: GET');
    store_json_response(['error' => 'method_not_allowed'], 405, 'no-store');
}

try {
    $revocations = store_load_revocations();
    store_json_response($revocations, 200, 'public, max-age=60');
} catch (Throwable) {
    store_public_error();
}
