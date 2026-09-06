$ErrorActionPreference = 'Stop'

$branch = 'feat/ghosium-browser-v0.6-native-chromium'
$mainPath = 'src/main.ts'
$source = [System.IO.File]::ReadAllText((Join-Path $PWD $mainPath))
$startMarker = 'app.innerHTML = `'
$endMarker = 'const tabsEl ='
$start = $source.IndexOf($startMarker)
$end = $source.IndexOf($endMarker)
if ($start -lt 0 -or $end -le $start) {
    throw 'Unable to locate the Ghosium shell template boundaries.'
}

$template = @'
app.innerHTML = `
  <main class="browser-shell">
    <header class="browser-chrome" id="browser-chrome">
      <div class="tabstrip drag-region" id="drag-region">
        <div class="brand no-drag" aria-label="Ghosium Browser" title="Ghosium Browser">
          <span class="ghosium-mark text-aurora" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path d="M6.5 19V10.6a5.5 5.5 0 0 1 11 0V19l-2.2-1.7L13.7 19 12 17.4 10.3 19l-1.6-1.7L6.5 19Z"/><path d="M9.4 11.2h.01M14.6 11.2h.01"/></svg>
          </span>
        </div>
        <div class="tabs no-drag" id="tabs"></div>
        <button class="chrome-button new-tab-button no-drag" id="new-tab" title="Novi tab" aria-label="Novi tab">+</button>
        <div class="window-controls no-drag">
          <button id="minimize" class="window-button" aria-label="Minimiziraj"><svg class="ui-icon" viewBox="0 0 24 24"><path d="M6 12h12"/></svg></button>
          <button id="maximize" class="window-button" aria-label="Maksimiziraj"><svg class="ui-icon" viewBox="0 0 24 24"><rect x="7" y="7" width="10" height="10" rx="1"/></svg></button>
          <button id="close-window" class="window-button close" aria-label="Zatvori"><svg class="ui-icon" viewBox="0 0 24 24"><path d="m8 8 8 8m0-8-8 8"/></svg></button>
        </div>
      </div>

      <div class="toolbar no-drag">
        <div class="nav-cluster">
          <button id="back" class="icon-button" title="Natrag" aria-label="Natrag"><svg class="ui-icon" viewBox="0 0 24 24"><path d="m14.5 6-6 6 6 6"/></svg></button>
          <button id="forward" class="icon-button" title="Naprijed" aria-label="Naprijed"><svg class="ui-icon" viewBox="0 0 24 24"><path d="m9.5 6 6 6-6 6"/></svg></button>
          <button id="reload" class="icon-button" title="Osvježi" aria-label="Osvježi"><svg class="ui-icon" viewBox="0 0 24 24"><path d="M18 8a7 7 0 1 0 1 7"/><path d="M18 4v4h-4"/></svg></button>
        </div>

        <form id="omnibox-form" class="omnibox" autocomplete="off">
          <span id="connection-icon" class="connection-icon" aria-hidden="true">●</span>
          <input id="omnibox" type="text" spellcheck="false" autocapitalize="off" autocomplete="off"
                 maxlength="8192" aria-label="Adresa i pretraživanje" aria-autocomplete="list"
                 aria-controls="omnibox-suggestions" aria-expanded="false"
                 placeholder="Pretraži web ili upiši adresu" />
          <button type="button" id="shield" class="shield" title="Ghosium zaštita" aria-label="Ghosium zaštita">
            <svg class="ui-icon shield-svg" viewBox="0 0 24 24"><path d="M12 3 19 6v5c0 4.8-2.9 8.2-7 10-4.1-1.8-7-5.2-7-10V6l7-3Z"/><path d="m9 12 2 2 4-4"/></svg>
            <span id="blocked-count">0</span>
          </button>
          <div id="omnibox-suggestions" class="omnibox-suggestions" role="listbox" aria-label="Prijedlozi pretraživanja"></div>
        </form>

        <button id="privacy" class="icon-button toolbar-action" title="Privatnost" aria-label="Privatnost"><svg class="ui-icon" viewBox="0 0 24 24"><path d="M12 3 19 6v5c0 4.8-2.9 8.2-7 10-4.1-1.8-7-5.2-7-10V6l7-3Z"/></svg></button>
        <button id="menu" class="icon-button toolbar-action" title="Izbornik" aria-label="Izbornik" aria-expanded="false"><svg class="ui-icon" viewBox="0 0 24 24"><circle cx="6" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="18" cy="12" r="1"/></svg></button>
      </div>
    </header>

    <section class="newtab" id="newtab">
      <div class="aur aur-one" aria-hidden="true"></div>
      <div class="aur aur-two" aria-hidden="true"></div>
      <div class="newtab-inner">
        <div class="hero-mark text-aurora" aria-hidden="true">
          <svg viewBox="0 0 24 24"><path d="M6.5 19V10.6a5.5 5.5 0 0 1 11 0V19l-2.2-1.7L13.7 19 12 17.4 10.3 19l-1.6-1.7L6.5 19Z"/><path d="M9.4 11.2h.01M14.6 11.2h.01"/></svg>
        </div>
        <p class="newtab-eyebrow">GHOSIUM BROWSER</p>
        <h1>Web bez suvišnog traga.</h1>
        <p class="newtab-subtitle">Privatno pregledavanje, lokalni podaci i zaštita od poznatih trackera — bez Ghosium analitike i profiliranja.</p>

        <form id="newtab-search" class="newtab-search suggestion-host" autocomplete="off">
          <svg class="ui-icon search-icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.5"/><path d="m16 16 4 4"/></svg>
          <input id="newtab-input" type="text" maxlength="8192"
                 placeholder="Pretraži web ili upiši adresu" spellcheck="false" autocomplete="off"
                 aria-label="Pretraživanje ili web-adresa" aria-autocomplete="list"
                 aria-controls="newtab-suggestions" aria-expanded="false" />
          <div id="newtab-suggestions" class="omnibox-suggestions newtab-suggestions" role="listbox" aria-label="Prijedlozi pretraživanja"></div>
        </form>

        <div class="privacy-cards" aria-label="Aktivna zaštita">
          <article>
            <span class="card-kicker">● Aktivno</span>
            <strong>Tracker zaštita</strong>
            <span>Poznati trackeri i oglasni zahtjevi blokiraju se prije prikaza.</span>
          </article>
          <article>
            <span class="card-kicker">● Lokalno</span>
            <strong>Vaši podaci</strong>
            <span>Favoriti, povijest i postavke ostaju u lokalnom Ghosium profilu.</span>
          </article>
          <article>
            <span class="card-kicker">● Pametno</span>
            <strong>Memory Saver</strong>
            <span>Neaktivni tabovi oslobađaju resurse i vraćaju se kada ih otvorite.</span>
          </article>
        </div>
      </div>
    </section>

    <aside class="panel" id="privacy-panel" aria-hidden="true">
      <div class="panel-header">
        <div><small>GHOSIUM ZAŠTITA</small><h2>Privatnost</h2></div>
        <button id="close-panel" class="icon-button" aria-label="Zatvori"><svg class="ui-icon" viewBox="0 0 24 24"><path d="m8 8 8 8m0-8-8 8"/></svg></button>
      </div>
      <div class="panel-status">
        <span class="status-dot"></span>
        <div><strong>Zaštita je aktivna</strong><p>Ghosium Browser nema vlastitu analitiku, oglasne identifikatore ni korisničko profiliranje.</p></div>
      </div>
      <div class="setting"><div><strong>Reklame i trackeri</strong><span>Blokiranje poznatih mreža za oglašavanje i praćenje</span></div><span class="status-badge">Uključeno</span></div>
      <div class="setting"><div><strong>Dozvole web-stranice</strong><span>Kamera, mikrofon i lokacija traže dopuštenje nakon vaše radnje</span></div><span class="status-badge">Na zahtjev</span></div>
      <div class="setting"><div><strong>Privacy signali</strong><span>Do Not Track i Global Privacy Control</span></div><span class="status-badge">Uključeno</span></div>
      <div class="panel-actions"><button id="clear-data" class="primary-button">Obriši podatke pregledavanja</button></div>
    </aside>

    <aside class="app-menu" id="app-menu" aria-hidden="true">
      <div class="menu-head"><span class="menu-eyebrow">GHOSIUM</span><strong class="menu-title">Preglednik</strong></div>
      <button class="menu-item" id="menu-new-tab"><span>Novi tab</span><kbd>Ctrl+T</kbd></button>
      <button class="menu-item" id="menu-reopen-tab"><span>Ponovno otvori zatvoreni tab</span><kbd>Ctrl+Shift+T</kbd></button>
      <div class="menu-separator"></div>
      <button class="menu-item" id="menu-memory-saver"><span>Oslobodi memoriju neaktivnih tabova</span></button>
      <div class="menu-status" id="memory-status">Memory Saver</div>
      <button class="menu-item" id="menu-clear-data"><span>Obriši podatke pregledavanja</span></button>
      <div class="menu-separator"></div>
      <div class="menu-footer"><strong>Ghosium Browser</strong><span>Brendigo · privatno pregledavanje za Windows</span></div>
    </aside>

    <div class="toast" id="toast" role="status" aria-live="polite"></div>
  </main>`;
'@

$updated = $source.Substring(0, $start) + $template + "`n`n" + $source.Substring($end)
[System.IO.File]::WriteAllText((Join-Path $PWD $mainPath), $updated, [System.Text.UTF8Encoding]::new($false))

$stylesPath = Join-Path $PWD 'src/styles.css'
$styles = [System.IO.File]::ReadAllText($stylesPath)
if (-not $styles.Contains('.ui-icon {')) {
    $styles += @'

.ui-icon {
  width: 17px;
  height: 17px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.7;
  stroke-linecap: round;
  stroke-linejoin: round;
  pointer-events: none;
}

.shield-svg {
  width: 15px;
  height: 15px;
}
'@
    [System.IO.File]::WriteAllText($stylesPath, $styles, [System.Text.UTF8Encoding]::new($false))
}

New-Item -ItemType Directory -Force -Path 'fonts' | Out-Null
$fontUrl = 'https://raw.githubusercontent.com/rsms/inter/v4.1/docs/font-files/InterVariable.woff2'
$licenseUrl = 'https://raw.githubusercontent.com/rsms/inter/v4.1/LICENSE.txt'
Invoke-WebRequest -Uri $fontUrl -OutFile 'fonts/inter-var.woff2'
Invoke-WebRequest -Uri $licenseUrl -OutFile 'fonts/INTER-LICENSE.txt'
$font = Get-Item 'fonts/inter-var.woff2'
if ($font.Length -lt 100KB) {
    throw "Downloaded Inter font is unexpectedly small: $($font.Length) bytes"
}
$hash = (Get-FileHash 'fonts/inter-var.woff2' -Algorithm SHA256).Hash.ToLowerInvariant()
@"
Ghosium Browser bundles Inter 4.1 locally.
Upstream: https://github.com/rsms/inter/releases/tag/v4.1
File: fonts/inter-var.woff2
SHA256: $hash
Weights used by Ghosium: 400, 500, 600, 700, 800 (variable font range).
"@ | Set-Content 'fonts/INTER-SOURCE.txt' -Encoding utf8

npm ci
if ($LASTEXITCODE -ne 0) { throw 'npm ci failed before UI validation.' }
npm run build
if ($LASTEXITCODE -ne 0) { throw 'Frontend build failed after Ghosium redesign.' }

$mainCheck = [System.IO.File]::ReadAllText((Join-Path $PWD $mainPath))
foreach ($required in @('class="aur aur-one"', 'class="aur aur-two"', 'newtab-eyebrow', 'Ghosium Browser', 'id="omnibox"', 'id="privacy-panel"', 'id="app-menu"')) {
    if (-not $mainCheck.Contains($required)) { throw "Redesigned shell is missing required marker: $required" }
}
$stylesCheck = [System.IO.File]::ReadAllText($stylesPath)
foreach ($required in @('@keyframes floataur', '.aur {', '--aurora: oklch(0.858 0.132 164.6)', '--neon: oklch(0.789 0.135 212.1)', '--violet-glow: oklch(0.75 0.14 295.2)', 'font-family: "Inter"')) {
    if (-not $stylesCheck.Contains($required)) { throw "Design system is missing required marker: $required" }
}

$remoteFont = Select-String -Path 'index.html','src/*.css','src/*.ts' -Pattern 'fonts\.googleapis\.com|fonts\.gstatic\.com|rsms\.me/inter/inter\.css' -Quiet
if ($remoteFont) { throw 'Remote font dependency detected.' }

$changes = @(git status --short)
if ($changes.Count -eq 0) { throw 'Ghosium redesign produced no changes.' }

git config user.name 'Brendigo'
git config user.email 'info@brendigo.com'
git add src/main.ts src/styles.css fonts/inter-var.woff2 fonts/INTER-LICENSE.txt fonts/INTER-SOURCE.txt

git commit -m 'Rebuild Ghosium browser chrome and new-tab experience'
if ($LASTEXITCODE -ne 0) { throw 'Unable to commit Ghosium redesign.' }
git push origin HEAD:$branch
if ($LASTEXITCODE -ne 0) { throw 'Unable to push Ghosium redesign.' }
