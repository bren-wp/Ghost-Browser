<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: public, max-age=300');
header('Referrer-Policy: no-referrer');
header('X-Content-Type-Options: nosniff');
header('Access-Control-Allow-Origin: https://store.ghosium.com');

$file = dirname(__DIR__) . '/storage/data/extensions.json';
if (!is_file($file)) {
    http_response_code(503);
    echo json_encode(['extensions' => []], JSON_UNESCAPED_SLASHES);
    exit;
}

$data = json_decode((string)file_get_contents($file), true);
if (!is_array($data)) {
    http_response_code(500);
    echo json_encode(['extensions' => []], JSON_UNESCAPED_SLASHES);
    exit;
}

echo json_encode(['extensions' => $data], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
