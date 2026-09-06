$ErrorActionPreference = 'Stop'

$branch = 'feat/ghosium-browser-v0.6-native-chromium'
$files = @('src/styles.css', 'src/browser-ui.css', 'src/library.css')
$map = [ordered]@{
  '450' = '500'
  '520' = '500'
  '540' = '500'
  '550' = '600'
  '580' = '600'
  '590' = '600'
  '620' = '600'
  '650' = '600'
  '680' = '700'
  '720' = '700'
  '750' = '800'
}

foreach ($file in $files) {
  $text = [System.IO.File]::ReadAllText((Join-Path $PWD $file))
  foreach ($entry in $map.GetEnumerator()) {
    $text = $text.Replace("font-weight: $($entry.Key);", "font-weight: $($entry.Value);")
  }
  [System.IO.File]::WriteAllText((Join-Path $PWD $file), $text, [System.Text.UTF8Encoding]::new($false))
}

$bad = @()
foreach ($file in $files) {
  $text = [System.IO.File]::ReadAllText((Join-Path $PWD $file))
  foreach ($match in [regex]::Matches($text, 'font-weight:\s*(\d{3})\s*;')) {
    $weight = $match.Groups[1].Value
    if ($weight -notin @('400','500','600','700','800')) {
      $bad += "$file -> $weight"
    }
  }
}
if ($bad.Count -gt 0) { throw "Unsupported Inter weights remain:`n$($bad -join "`n")" }

npm ci
if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' }
npm run build
if ($LASTEXITCODE -ne 0) { throw 'Frontend build failed after weight normalization.' }

git config user.name 'Brendigo'
git config user.email 'info@brendigo.com'
git add $files
git commit -m 'Normalize Ghosium typography to approved Inter weights'
if ($LASTEXITCODE -ne 0) { throw 'No typography normalization commit was produced.' }
git push origin HEAD:$branch
if ($LASTEXITCODE -ne 0) { throw 'Unable to push typography normalization.' }
