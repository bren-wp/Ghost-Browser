<?php
declare(strict_types=1);

$catalogFile = __DIR__ . '/storage/data/extensions.json';
$catalog = [];
if (is_file($catalogFile)) {
    $decoded = json_decode((string)file_get_contents($catalogFile), true);
    if (is_array($decoded)) {
        $catalog = $decoded;
    }
}

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

header('Content-Type: text/html; charset=UTF-8');
header('Referrer-Policy: no-referrer');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header("Content-Security-Policy: default-src 'self'; img-src 'self'; style-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'");
?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="referrer" content="no-referrer">
  <title>Ghosium Store</title>
  <meta name="description" content="Official Ghosium Browser extension catalog.">
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body>
  <header class="topbar">
    <a class="brand" href="https://ghosium.com/" aria-label="Ghosium home">Ghosium <strong>Store</strong></a>
    <nav aria-label="Ghosium">
      <a href="https://search.ghosium.com/">Search</a>
      <a href="https://ghosium.com/support">Support</a>
      <a href="https://ghosium.com/security">Security</a>
    </nav>
  </header>

  <main>
    <section class="hero">
      <p class="eyebrow">OFFICIAL GHOSIUM CATALOG</p>
      <h1>Extensions, the <span>Ghosium way.</span></h1>
      <p>Curated extension metadata hosted on Ghosium infrastructure. No advertising SDKs, no remote fonts and no third-party assets are used by this store.</p>
    </section>

    <section class="catalog" aria-label="Extension catalog">
      <?php foreach ($catalog as $extension):
        $name = (string)($extension['name'] ?? 'Ghosium Extension');
        $description = (string)($extension['description'] ?? '');
        $version = (string)($extension['version'] ?? '');
        $status = (string)($extension['status'] ?? 'coming_soon');
      ?>
        <article class="card">
          <div class="icon" aria-hidden="true">G</div>
          <div class="card-copy">
            <div class="card-topline">
              <h2><?= e($name) ?></h2>
              <span class="badge"><?= e(str_replace('_', ' ', strtoupper($status))) ?></span>
            </div>
            <p><?= e($description) ?></p>
            <small><?= $version !== '' ? 'Version ' . e($version) : 'Managed by Ghosium' ?></small>
          </div>
        </article>
      <?php endforeach; ?>

      <?php if ($catalog === []): ?>
        <article class="card empty"><h2>Catalog is being prepared.</h2><p>Official Ghosium extensions will appear here after review.</p></article>
      <?php endif; ?>
    </section>

    <section class="notice">
      <h2>Safe distribution first.</h2>
      <p>Ghosium Store starts as a vetted catalog. Automatic one-click installation from a private public store requires deeper browser-engine integration and will only be enabled after it can be implemented without weakening extension security.</p>
    </section>
  </main>

  <footer>
    <span>© 2026 Brendigo · Ghosium Store</span>
    <nav aria-label="Legal">
      <a href="https://ghosium.com/legal/terms">Terms</a>
      <a href="https://ghosium.com/legal/privacy-policy">Privacy</a>
      <a href="https://ghosium.com/legal/licenses">Licenses</a>
    </nav>
  </footer>
</body>
</html>
