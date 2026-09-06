$ErrorActionPreference = 'Stop'

$baseline = 'df9b823eba99b2ea7bc2167eb2d63ea01421560d'
$branch = 'fix/ghosium-main-regression'
$restore = @(
  'README.md',
  'index.html',
  'src-tauri/src/privacy.rs',
  'src-tauri/src/webview2_guard.rs'
)

$downloadFiles = @('src/downloads.ts', 'src/downloads.css')
$before = @{}
foreach ($file in $downloadFiles) {
  if (Test-Path $file) {
    $before[$file] = (Get-FileHash $file -Algorithm SHA256).Hash
  }
}

git checkout $baseline -- $restore
if ($LASTEXITCODE -ne 0) { throw 'Unable to restore verified Ghosium baseline files.' }

foreach ($file in $downloadFiles) {
  if ($before.ContainsKey($file)) {
    $after = (Get-FileHash $file -Algorithm SHA256).Hash
    if ($after -ne $before[$file]) { throw "Unrelated download file changed: $file" }
  }
}

$legacy = 'gh' + 'ost'
$matches = @(git grep -I -n -i -- $legacy -- README.md index.html src-tauri/src/privacy.rs src-tauri/src/webview2_guard.rs 2>$null)
$grepExit = $LASTEXITCODE
if ($grepExit -eq 0) { throw "Legacy branding remains in restored production files:`n$($matches -join "`n")" }
if ($grepExit -ne 1) { throw "Brand scan failed with exit code $grepExit" }

$index = Get-Content 'index.html' -Raw
if (-not $index.Contains('/src/library.ts')) { throw 'Library bootstrap was not restored.' }
$privacy = Get-Content 'src-tauri/src/privacy.rs' -Raw
foreach ($required in @('doNotTrack', 'globalPrivacyControl')) {
  if (-not $privacy.Contains($required)) { throw "Privacy baseline missing $required" }
}
$guard = Get-Content 'src-tauri/src/webview2_guard.rs' -Raw
foreach ($required in @('PermissionRequestedEventHandler', 'WebResourceRequestedEventHandler')) {
  if (-not $guard.Contains($required)) { throw "WebView2 guard baseline missing $required" }
}

git config user.name 'Brendigo'
git config user.email 'info@brendigo.com'
git add $restore
git commit -m 'Restore verified Ghosium v0.5.1 production baseline'
if ($LASTEXITCODE -ne 0) { throw 'No restoration commit was produced.' }
git push origin HEAD:$branch
if ($LASTEXITCODE -ne 0) { throw 'Unable to push Ghosium baseline restoration.' }
