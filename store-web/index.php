<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/store.php';

$catalog = [];
$storeAvailable = true;
try {
    $validatedCatalog = store_load_catalog(false);
    $revocations = store_load_revocations();
    $catalog = store_public_catalog($validatedCatalog, $revocations)['extensions'];
} catch (Throwable) {
    $storeAvailable = false;
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
  <meta name="description" content="Official Ghosium Browser extension catalog with verified distribution metadata.">
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
      <p>First-party catalog and trust metadata hosted on Ghosium infrastructure, without advertising SDKs, remote fonts or third-party page assets.</p>
    </section>

    <section class="catalog" aria-label="Extension catalog">
      <?php foreach ($catalog as $extension):
        $name = (string)($extension['name'] ?? 'Ghosium Extension');
        $description = (string)($extension['description'] ?? '');
        $version = (string)($extension['version'] ?? '');
        $status = (string)($extension['status'] ?? '');
        $revoked = ($extension['revoked'] ?? false) === true;
        $permissions = is_array($extension['permissions'] ?? null) ? $extension['permissions'] : [];
        $hostPermissions = is_array($extension['hostPermissions'] ?? null) ? $extension['hostPermissions'] : [];
        $permissionCount = count($permissions) + count($hostPermissions);
        $badge = $revoked ? 'REVOKED' : ($status === 'built_in' ? 'BUILT IN' : 'VERIFIED');
      ?>
        <article class="card">
          <div class="icon" aria-hidden="true">G</div>
          <div class="card-copy">
            <div class="card-topline">
              <h2><?= e($name) ?></h2>
              <span class="badge"><?= e($badge) ?></span>
            </div>
            <p><?= e($description) ?></p>
            <small>Version <?= e($version) ?> · Manifest V<?= e((string)($extension['manifestVersion'] ?? 3)) ?> · <?= e((string)$permissionCount) ?> declared permission<?= $permissionCount === 1 ? '' : 's' ?></small>
          </div>
        </article>
      <?php endforeach; ?>

      <?php if (!$storeAvailable): ?>
        <article class="card empty"><h2>Store temporarily unavailable.</h2><p>Catalog validation failed, so no extension metadata is being served.</p></article>
      <?php elseif ($catalog === []): ?>
        <article class="card empty"><h2>No extensions available.</h2><p>No extension currently satisfies the Ghosium Store publication contract.</p></article>
      <?php endif; ?>
    </section>

    <section class="notice">
      <h2>Verified distribution.</h2>
      <p>Downloadable packages must use Manifest V3, an approved permission review, a package-bound malware scan record, SHA-256 integrity metadata and an Ed25519 signature from an active Ghosium Store signing key. Revoked versions are blocked from update delivery.</p>
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
