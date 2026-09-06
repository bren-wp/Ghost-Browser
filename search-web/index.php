<?php
declare(strict_types=1);

require_once __DIR__ . '/inc/search.php';
ghosium_headers(false);
rate_limit_or_fail();

$query = normalize_query((string)($_GET['q'] ?? ''));
$results = $query !== '' ? ghosium_search($query) : [];
if ($query !== '') {
    header('X-Robots-Tag: noindex, nofollow, noarchive');
}

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="referrer" content="no-referrer">
  <?php if ($query !== ''): ?><meta name="robots" content="noindex,nofollow,noarchive"><?php endif; ?>
  <title><?= $query !== '' ? e($query) . ' — ' : '' ?>Ghosium Search</title>
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body class="<?= $query === '' ? 'home' : 'results-page' ?>">
  <header class="topbar">
    <a class="brand" href="/" aria-label="Ghosium Search home">
      <img src="/assets/ghosium-mark.svg" alt="" width="34" height="34">
      <span>Ghosium <strong>Search</strong></span>
    </a>
    <?php if ($query !== ''): ?>
      <form class="top-search" method="get" action="/" role="search">
        <label class="sr-only" for="top-q">Search the web</label>
        <input id="top-q" name="q" type="search" value="<?= e($query) ?>" autocomplete="off" maxlength="180">
        <button type="submit">Search</button>
      </form>
    <?php endif; ?>
  </header>

  <main>
    <?php if ($query === ''): ?>
      <section class="hero">
        <img class="hero-mark" src="/assets/ghosium-mark.svg" alt="" width="88" height="88">
        <p class="eyebrow">PRIVATE BY DESIGN</p>
        <h1>Ghosium <span>Search</span></h1>
        <p class="lead">Search through the Ghosium endpoint without application advertising profiles or raw-query storage in the Ghosium application.</p>
        <form class="hero-search" method="get" action="/" role="search">
          <label class="sr-only" for="q">Ghosium Search</label>
          <input id="q" name="q" type="search" autofocus autocomplete="off" maxlength="180" placeholder="Search the web">
          <button type="submit">Search</button>
        </form>
        <p class="privacy-note">No tracking cookies · no account required · first-party JSON index</p>
      </section>
    <?php else: ?>
      <section class="results" aria-labelledby="results-title">
        <p class="count" id="results-title"><?= count($results) ?> results for <strong><?= e($query) ?></strong></p>
        <?php if ($results === []): ?>
          <article class="empty">
            <h2>No results in the current index.</h2>
            <p>Add more seed domains and run the crawler, or enable your own compatible server-side JSON provider.</p>
          </article>
        <?php endif; ?>
        <?php foreach ($results as $result):
          $host = (string)(parse_url((string)$result['url'], PHP_URL_HOST) ?: '');
        ?>
          <article class="result">
            <div class="result-host"><?= e($host) ?></div>
            <h2><a href="<?= e((string)$result['url']) ?>" rel="noopener noreferrer"><?= e((string)$result['title']) ?></a></h2>
            <?php if ((string)$result['description'] !== ''): ?><p><?= e((string)$result['description']) ?></p><?php endif; ?>
          </article>
        <?php endforeach; ?>
      </section>
    <?php endif; ?>
  </main>

  <footer>
    <span>Ghosium Search</span>
    <nav aria-label="Ghosium links">
      <a href="https://ghosium.com/">Home</a>
      <a href="https://store.ghosium.com/">Store</a>
      <a href="https://ghosium.com/support">Support</a>
      <a href="https://ghosium.com/security">Security</a>
      <a href="https://ghosium.com/legal/terms">Terms</a>
      <a href="https://ghosium.com/legal/privacy-policy">Privacy</a>
      <a href="https://ghosium.com/legal/licenses">Licenses</a>
      <a href="/health.php">Status</a>
    </nav>
  </footer>
</body>
</html>
