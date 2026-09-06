<?php
declare(strict_types=1);

require_once __DIR__ . '/../inc/search.php';
rate_limit_or_fail();
$query = normalize_query((string)($_GET['q'] ?? ''));
json_response([$query, $query === '' ? [] : ghosium_suggestions($query)]);
