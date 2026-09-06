<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit("CLI only\n");
}

require_once __DIR__ . '/../inc/bootstrap.php';

function public_web_url(string $url): bool
{
    $parts = parse_url($url);
    if (!is_array($parts) || !isset($parts['scheme'], $parts['host'])) return false;
    if (!in_array(strtolower((string)$parts['scheme']), ['http', 'https'], true)) return false;
    $host = strtolower((string)$parts['host']);
    if ($host === 'localhost' || str_ends_with($host, '.local')) return false;
    if (filter_var($host, FILTER_VALIDATE_IP)) {
        return filter_var($host, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) !== false;
    }
    $addresses = gethostbynamel($host) ?: [];
    if ($addresses === []) return false;
    foreach ($addresses as $address) {
        if (filter_var($address, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false) return false;
    }
    return true;
}

function fetch_html(string $url, string $userAgent): array
{
    if (!function_exists('curl_init') || !public_web_url($url)) return ['', ''];
    $handle = curl_init($url);
    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS => 3,
        CURLOPT_CONNECTTIMEOUT => 4,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_USERAGENT => $userAgent,
        CURLOPT_HTTPHEADER => ['Accept: text/html,application/xhtml+xml'],
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $body = curl_exec($handle);
    $status = (int)curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    $type = strtolower((string)curl_getinfo($handle, CURLINFO_CONTENT_TYPE));
    $effective = (string)curl_getinfo($handle, CURLINFO_EFFECTIVE_URL);
    curl_close($handle);
    if (!is_string($body) || $status < 200 || $status >= 300 || !str_contains($type, 'text/html') || strlen($body) > 2_000_000) {
        return ['', ''];
    }
    return [$body, $effective !== '' ? $effective : $url];
}

function canonicalize_link(string $base, string $href): string
{
    $href = trim($href);
    if ($href === '' || str_starts_with($href, '#') || preg_match('/^(mailto|tel|javascript):/i', $href)) return '';
    if (preg_match('#^https?://#i', $href)) return clean_result_url($href);
    $baseParts = parse_url($base);
    if (!is_array($baseParts) || !isset($baseParts['scheme'], $baseParts['host'])) return '';
    if (str_starts_with($href, '//')) return clean_result_url($baseParts['scheme'] . ':' . $href);
    if (str_starts_with($href, '/')) return clean_result_url($baseParts['scheme'] . '://' . $baseParts['host'] . $href);
    $path = (string)($baseParts['path'] ?? '/');
    $directory = rtrim(str_replace('\\', '/', dirname($path)), '/');
    return clean_result_url($baseParts['scheme'] . '://' . $baseParts['host'] . ($directory === '' ? '' : $directory) . '/' . $href);
}

$config = ghosium_config();
$crawler = $config['crawler'] ?? [];
$maxPages = max(1, min(500, (int)($crawler['max_pages'] ?? 40)));
$maxDepth = max(0, min(4, (int)($crawler['max_depth'] ?? 2)));
$userAgent = trim((string)($crawler['user_agent'] ?? 'GhosiumSearchBot/0.6'));
$seeds = json_read(GHOSIUM_DATA . '/seeds.json');
$queue = [];
$seedHosts = [];
foreach ($seeds as $seed) {
    $url = clean_result_url((string)$seed);
    $host = strtolower((string)(parse_url($url, PHP_URL_HOST) ?: ''));
    if ($url !== '' && $host !== '') {
        $queue[] = [$url, 0];
        $seedHosts[$host] = true;
    }
}

$seen = [];
$index = [];
while ($queue !== [] && count($index) < $maxPages) {
    [$url, $depth] = array_shift($queue);
    if (isset($seen[$url])) continue;
    $seen[$url] = true;
    [$html, $effective] = fetch_html($url, $userAgent);
    if ($html === '') continue;

    $dom = new DOMDocument();
    libxml_use_internal_errors(true);
    $loaded = $dom->loadHTML($html, LIBXML_NOERROR | LIBXML_NOWARNING);
    libxml_clear_errors();
    if (!$loaded) continue;

    $title = trim((string)($dom->getElementsByTagName('title')->item(0)?->textContent ?? ''));
    $description = '';
    foreach ($dom->getElementsByTagName('meta') as $meta) {
        if (strtolower((string)$meta->getAttribute('name')) === 'description') {
            $description = trim((string)$meta->getAttribute('content'));
            break;
        }
    }
    if ($title !== '') {
        $index[] = [
            'url' => clean_result_url($effective),
            'title' => function_exists('mb_substr') ? mb_substr($title, 0, 180, 'UTF-8') : substr($title, 0, 180),
            'description' => function_exists('mb_substr') ? mb_substr(strip_tags($description), 0, 420, 'UTF-8') : substr(strip_tags($description), 0, 420),
            'tags' => [(string)(parse_url($effective, PHP_URL_HOST) ?: '')],
            'indexed_at' => gmdate('c'),
        ];
    }

    if ($depth >= $maxDepth) continue;
    foreach ($dom->getElementsByTagName('a') as $anchor) {
        $next = canonicalize_link($effective, (string)$anchor->getAttribute('href'));
        if ($next === '' || isset($seen[$next])) continue;
        $host = strtolower((string)(parse_url($next, PHP_URL_HOST) ?: ''));
        if (!isset($seedHosts[$host])) continue;
        $queue[] = [$next, $depth + 1];
        if (count($queue) > $maxPages * 10) break;
    }
    usleep(150000);
}

if (!json_write_atomic(GHOSIUM_DATA . '/index.json', $index)) {
    fwrite(STDERR, "Unable to write index.json\n");
    exit(1);
}

echo 'Indexed ' . count($index) . " pages.\n";
