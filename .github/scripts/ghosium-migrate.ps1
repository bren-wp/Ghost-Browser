$ErrorActionPreference = 'Stop'

$legacyLower = 'gh' + 'ost'
$legacyTitle = 'Gh' + 'ost'
$legacyUpper = 'GH' + 'OST'

$textFiles = @(git grep -Il -i -- $legacyLower -- . 2>$null)
if ($LASTEXITCODE -notin @(0, 1)) {
    throw 'Unable to enumerate legacy branding in tracked text files.'
}

foreach ($file in $textFiles) {
    $path = Join-Path $PWD $file
    $text = [System.IO.File]::ReadAllText($path)
    $text = $text.Replace("$legacyTitle Browser", 'Ghosium Browser')
    $text = $text.Replace("$legacyUpper BROWSER", 'GHOSIUM BROWSER')
    $text = $text.Replace("$legacyLower-browser", 'ghosium-browser')
    $text = $text.Replace("${legacyLower}_browser", 'ghosium_browser')
    $text = $text.Replace("${legacyTitle}Browser", 'GhosiumBrowser')
    $text = $text.Replace("${legacyLower}browser", 'ghosiumbrowser')
    $text = $text.Replace("${legacyLower}://", 'ghosium://')
    $text = $text.Replace($legacyTitle, 'Ghosium')
    $text = $text.Replace($legacyUpper, 'GHOSIUM')
    $text = $text.Replace($legacyLower, 'ghosium')
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
}

$legacyPaths = @(git ls-files | Where-Object { $_ -match "(?i)$legacyLower" })
foreach ($oldPath in $legacyPaths) {
    $newPath = $oldPath -replace "(?i)$legacyLower", 'ghosium'
    if ($newPath -ne $oldPath) {
        $newParent = Split-Path -Parent $newPath
        if ($newParent) {
            New-Item -ItemType Directory -Force -Path $newParent | Out-Null
        }
        git mv -- $oldPath $newPath
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to rename $oldPath"
        }
    }
}

npm install --package-lock-only --ignore-scripts
if ($LASTEXITCODE -ne 0) {
    throw 'npm lockfile generation failed.'
}

cargo generate-lockfile --manifest-path src-tauri/Cargo.toml
if ($LASTEXITCODE -ne 0) {
    throw 'Cargo lockfile generation failed.'
}

$badPaths = @(git ls-files | Where-Object { $_ -match "(?i)$legacyLower" })
if ($badPaths.Count -gt 0) {
    throw "Legacy branding remains in tracked paths: $($badPaths -join ', ')"
}

$matches = @(git grep -I -n -i -- $legacyLower -- . 2>$null)
if ($LASTEXITCODE -eq 0) {
    throw "Legacy branding remains in tracked text:`n$($matches -join "`n")"
}
if ($LASTEXITCODE -ne 1) {
    throw "Final branding scan failed with exit code $LASTEXITCODE"
}

git config user.name 'Brendigo'
git config user.email 'info@brendigo.com'
git add -A
git status --short
git commit -m 'Complete Ghosium Browser rebrand and generate dependency locks'
if ($LASTEXITCODE -ne 0) {
    throw 'Migration commit failed.'
}

git push origin HEAD:fix/v0.5.1-data-release-integrity
if ($LASTEXITCODE -ne 0) {
    throw 'Migration push failed.'
}
