<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

function query_tokens(string $query): array
{
    $parts = preg_split('/[^\p{L}\p{N}]+/u', lower_text($query), -1, PREG_SPLIT_NO_EMPTY) ?: [];
    $parts = array_values(array_unique(array_filter($parts, static fn(string $token): bool => strlen($token) >= 2)));
    return array_slice($parts, 0, 12);
}

function local_search(string $query, int $limit): array
{
    $records = json_read(GHOSIUM_DATA . '/index.json');
    $needle = lower_text($query);
    $tokens = query_tokens($query);
    $scored = [];

    foreach ($records as $record) {
        if (!is_array($record)) {
            continue;
        }
        $title = trim((string)($record['title'] ?? ''));
        $url = clean_result_url((string)($record['url'] ?? ''));
        $description = trim((string)($record['description'] ?? ''));
        $tags = implode(' ', array_map('strval', is_array($record['tags'] ?? null) ? $record['tags'] : []));
        if ($title === '' || $url === '') {
            continue;
        }
        $titleLower = lower_text($title);
        $descriptionLower = lower_text($description);
        $urlLower = lower_text($url);
        $tagsLower = lower_text($tags);
        $score = 0;
        if ($needle !== '' && str_contains($titleLower, $needle)) {
            $score += 30;
        }
        if ($needle !== '' && str_contains($descriptionLower, $needle)) {
            $score += 12;
        }
        foreach ($tokens as $token) {
            if (str_contains($titleLower, $token)) $score += 8;
            if (str_contains($tagsLower, $token)) $score += 6;
            if (str_contains($descriptionLower, $token)) $score += 3;
            if (str_contains($urlLower, $token)) $score += 2;
        }
        if ($score <= 0) {
            continue;
        }
        $scored[] = [
            'title' => $title,
            'url' => $url,
            'description' => $description,
            'score' => $score,
            'source' => 'local',
        ];
    }

    usort($scored, static fn(array $a, array $b): int => ($b['score'] <=> $a['score']) ?: strcmp($a['title'], $b['title']));
    return array_slice($scored, 0, $limit);
}

function provider_search(string $query, int $limit): array
{
    $config = ghosium_config();
    $provider = $config['provider'] ?? [];
    if (empty($provider['enabled']) || empty($provider['endpoint']) || !function_exists('curl_init')) {
        return [];
    }

    $cachePath = GHOSIUM_DATA . '/cache.json';
    $cache = json_read($cachePath);
    $cacheKey = hash('sha256', lower_text($query));
    $ttl = max(60, (int)($config['cache_ttl_seconds'] ?? 600));
    $cached = $cache[$cacheKey] ?? null;
    if (is_array($cached) && (int)($cached['expires'] ?? 0) >= time() && is_array($cached['results'] ?? null)) {
        return array_slice($cached['results'], 0, $limit);
    }

    $endpoint = (string)$provider['endpoint'];
    $parts = parse_url($endpoint);
    if (!is_array($parts) || !in_array(strtolower((string)($parts['scheme'] ?? '')), ['https'], true)) {
        return [];
    }
    $separator = str_contains($endpoint, '?') ? '&' : '?';
    $url = $endpoint . $separator . rawurlencode((string)($provider['query_param'] ?? 'q')) . '=' . rawurlencode($query);

    $headers = ['Accept: application/json'];
    $apiKey = trim((string)($provider['api_key'] ?? ''));
    if ($apiKey !== '') {
        $headers[] = (string)($provider['auth_header'] ?? 'Authorization') . ': ' . (string)($provider['auth_prefix'] ?? 'Bearer ') . $apiKey;
    }

    $handle = curl_init($url);
    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_CONNECTTIMEOUT => 3,
        CURLOPT_TIMEOUT => max(3, min(12, (int)($provider['timeout_seconds'] ?? 6))),
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_USERAGENT => 'GhosiumSearch/0.6',
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $body = curl_exec($handle);
    $status = (int)curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);
    if (!is_string($body) || $status < 200 || $status >= 300) {
        return [];
    }

    $decoded = json_decode($body, true);
    $items = is_array($decoded) && is_array($decoded['results'] ?? null) ? $decoded['results'] : [];
    $results = [];
    foreach ($items as $item) {
        if (!is_array($item)) continue;
        $urlValue = clean_result_url((string)($item['url'] ?? ''));
        $title = trim((string)($item['title'] ?? ''));
        if ($urlValue === '' || $title === '') continue;
        $results[] = [
            'title' => $title,
            'url' => $urlValue,
            'description' => trim((string)($item['description'] ?? '')),
            'score' => 1,
            'source' => 'provider',
        ];
        if (count($results) >= $limit) break;
    }

    $cache[$cacheKey] = ['expires' => time() + $ttl, 'results' => $results];
    foreach ($cache as $key => $value) {
        if (!is_array($value) || (int)($value['expires'] ?? 0) < time()) unset($cache[$key]);
    }
    if (count($cache) > 500) {
        $cache = array_slice($cache, -500, null, true);
    }
    json_write_atomic($cachePath, $cache);
    return $results;
}

function ghosium_search(string $query): array
{
    $config = ghosium_config();
    $limit = max(1, min(50, (int)($config['max_results'] ?? 20)));
    $remote = provider_search($query, $limit);
    $local = local_search($query, $limit);
    $merged = [];
    $seen = [];
    foreach (array_merge($remote, $local) as $result) {
        $key = lower_text((string)$result['url']);
        if (isset($seen[$key])) continue;
        $seen[$key] = true;
        $merged[] = $result;
        if (count($merged) >= $limit) break;
    }
    return $merged;
}

function ghosium_suggestions(string $query, int $limit = 8): array
{
    $query = normalize_query($query);
    if ($query === '') return [];
    $records = json_read(GHOSIUM_DATA . '/index.json');
    $needle = lower_text($query);
    $suggestions = [];
    foreach ($records as $record) {
        if (!is_array($record)) continue;
        $title = trim((string)($record['title'] ?? ''));
        if ($title !== '' && str_contains(lower_text($title), $needle)) {
            $suggestions[$title] = true;
        }
        if (count($suggestions) >= $limit) break;
    }
    return array_slice(array_keys($suggestions), 0, $limit);
}
