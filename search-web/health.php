<?php
declare(strict_types=1);

require_once __DIR__ . '/inc/bootstrap.php';
$config = ghosium_config();
$index = json_read(GHOSIUM_DATA . '/index.json');
json_response([
    'status' => 'ok',
    'service' => 'Ghosium Search',
    'indexEntries' => count($index),
    'providerEnabled' => !empty($config['provider']['enabled']),
]);
