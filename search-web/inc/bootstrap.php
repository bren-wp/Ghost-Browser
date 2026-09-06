<?php
declare(strict_types=1);

const GHOSIUM_ROOT = __DIR__ . '/..';
const GHOSIUM_DATA = GHOSIUM_ROOT . '/storage/data';

function ghosium_headers(bool $api = false): void
{
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('Referrer-Policy: no-referrer');
    header('Permissions-Policy: camera=(), microphone=(), geolocation=(), browsing-topics=()');
    header("Content-Security-Policy: default-src 'self'; style-src 'self'; img-src 'self' data:; form-action 'self'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'");
    if ($api) {
        header('X-Robots-Tag: noindex, nofollow, noarchive');
        header('Cache-Control: no-store, max-age=0');
    }
}

function json_read(string $path, array $fallback = []): array
{
    if (!is_file($path)) {
        return $fallback;
    }
    $raw = file_get_contents($path);
    if ($raw === false || trim($raw) === '') {
        return $fallback;
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : $fallback;
}

function json_write_atomic(string $path, array $value): bool
{
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0750, true) && !is_dir($directory)) {
        return false;
    }
    $json = json_encode($value, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if ($json === false) {
        return false;
    }
    $temp = tempnam($directory, '.ghosium-');
    if ($temp === false) {
        return false;
    }
    $ok = file_put_contents($temp, $json . PHP_EOL, LOCK_EX) !== false;
    if ($ok) {
        @chmod($temp, 0640);
        $ok = @rename($temp, $path);
    }
    if (is_file($temp)) {
        @unlink($temp);
    }
    return $ok;
}

function ghosium_config(): array
{
    static $config = null;
    if (is_array($config)) {
        return $config;
    }
    $defaults = [
        'site_name' => 'Ghosium Search',
        'base_url' => 'https://search.ghosium.com',
        'max_results' => 20,
        'cache_ttl_seconds' => 600,
        'rate_limit' => ['enabled' => true, 'requests' => 120, 'window_seconds' => 600],
        'provider' => [
            'enabled' => false,
            'endpoint' => '',
            'api_key' => '',
            'auth_header' => 'Authorization',
            'auth_prefix' => 'Bearer ',
            'query_param' => 'q',
            'timeout_seconds' => 6,
        ],
        'crawler' => ['max_pages' => 40, 'max_depth' => 2, 'user_agent' => 'GhosiumSearchBot/0.6'],
    ];
    $stored = json_read(GHOSIUM_DATA . '/config.json');
    $config = array_replace_recursive($defaults, $stored);
    return $config;
}

function runtime_secret(): string
{
    $path = GHOSIUM_DATA . '/runtime.json';
    $runtime = json_read($path);
    if (isset($runtime['secret']) && is_string($runtime['secret']) && strlen($runtime['secret']) >= 32) {
        return $runtime['secret'];
    }
    try {
        $secret = bin2hex(random_bytes(32));
    } catch (Throwable) {
        $secret = hash('sha256', __FILE__ . '|' . microtime(true) . '|' . mt_rand());
    }
    json_write_atomic($path, ['secret' => $secret, 'created_at' => gmdate('c')]);
    return $secret;
}

function normalize_query(string $query): string
{
    $query = trim(preg_replace('/\s+/u', ' ', $query) ?? '');
    if (function_exists('mb_substr')) {
        $query = mb_substr($query, 0, 180, 'UTF-8');
    } else {
        $query = substr($query, 0, 180);
    }
    return $query;
}

function lower_text(string $text): string
{
    return function_exists('mb_strtolower') ? mb_strtolower($text, 'UTF-8') : strtolower($text);
}

function clean_result_url(string $url): string
{
    $parts = parse_url($url);
    if (!is_array($parts) || !isset($parts['scheme'], $parts['host'])) {
        return '';
    }
    $scheme = strtolower((string)$parts['scheme']);
    if (!in_array($scheme, ['http', 'https'], true)) {
        return '';
    }
    $query = [];
    if (!empty($parts['query'])) {
        parse_str((string)$parts['query'], $query);
        foreach (array_keys($query) as $key) {
            $lower = strtolower((string)$key);
            if (str_starts_with($lower, 'utm_') || in_array($lower, ['gclid', 'dclid', 'fbclid', 'msclkid', 'yclid', 'mc_cid', 'mc_eid'], true)) {
                unset($query[$key]);
            }
        }
    }
    $rebuilt = $scheme . '://' . $parts['host'];
    if (isset($parts['port'])) {
        $rebuilt .= ':' . (int)$parts['port'];
    }
    $rebuilt .= $parts['path'] ?? '/';
    if ($query !== []) {
        $rebuilt .= '?' . http_build_query($query, '', '&', PHP_QUERY_RFC3986);
    }
    return $rebuilt;
}

function rate_limit_or_fail(): void
{
    $config = ghosium_config()['rate_limit'] ?? [];
    if (empty($config['enabled'])) {
        return;
    }
    $limit = max(10, (int)($config['requests'] ?? 120));
    $window = max(60, (int)($config['window_seconds'] ?? 600));
    $bucket = intdiv(time(), $window);
    $ip = (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown');
    $key = hash_hmac('sha256', $ip . '|' . $bucket, runtime_secret());
    $path = GHOSIUM_DATA . '/rate-limit.json';
    $state = json_read($path);
    $now = time();
    foreach ($state as $storedKey => $item) {
        if (!is_array($item) || (int)($item['expires'] ?? 0) < $now) {
            unset($state[$storedKey]);
        }
    }
    $count = (int)($state[$key]['count'] ?? 0) + 1;
    $state[$key] = ['count' => $count, 'expires' => ($bucket + 1) * $window + 60];
    json_write_atomic($path, $state);
    if ($count > $limit) {
        http_response_code(429);
        header('Retry-After: ' . $window);
        exit('Previše zahtjeva. Pokušajte ponovno malo kasnije.');
    }
}

function json_response(mixed $payload, int $status = 200): never
{
    ghosium_headers(true);
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}
