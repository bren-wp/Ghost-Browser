param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $repoRoot 'engine/branding/product.json') -Raw | ConvertFrom-Json
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$legalChromiumIds = @(
  '4365115785552740256',
  '7681937895330411637'
)
$chromiumWord = [regex]::new('\bChromium\b')
$chromiumProductStem = [regex]::new('\bChromium(?=\p{Ll}|\b)')
$chromeProductStem = [regex]::new('\bChrome(?=\p{Ll}|\b)')

function Get-TranslationLocaleCode {
  param([Parameter(Mandatory = $true)][string]$Locale)

  switch ($Locale) {
    'en-US' { return $null }
    'nb' { return 'no' }
    'he' { return 'iw' }
    default { return $Locale }
  }
}

function Replace-ProductBrandingInBody {
  param(
    [Parameter(Mandatory = $true)][string]$Body,
    [Parameter(Mandatory = $true)][string]$TranslationId,
    [Parameter(Mandatory = $true)][bool]$PreserveChromiumProject
  )

  $updated = $Body
  $updated = $updated.Replace('Chrome Web Store', 'Ghosium Store')
  $updated = $updated.Replace('Google Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Google Chrome', 'Ghosium Browser')

  if ($PreserveChromiumProject -and $legalChromiumIds -contains $TranslationId) {
    # Legal messages deliberately retain Chromium as the upstream project name.
    # Replace only the first standalone product token and leave the linked
    # upstream project token intact.
    $updated = $chromiumWord.Replace($updated, 'Ghosium Browser', 1)
  } else {
    # Several locales inflect brand names (for example Croatian Chromiuma /
    # Chromiumu). Match a lowercase grammatical suffix as well as a standalone
    # token, but intentionally do not consume uppercase compounds such as
    # ChromiumOS/ChromeOS.
    $updated = $chromiumProductStem.Replace($updated, 'Ghosium Browser')
    $updated = $chromeProductStem.Replace($updated, 'Ghosium Browser')
  }

  $updated = $updated.Replace('Ghosium Browser browser', 'Ghosium Browser')
  return $updated
}

function Update-XtbBundle {
  param(
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][bool]$PreserveChromiumProject
  )

  $updatedFiles = 0
  foreach ($locale in @($config.locales.supported)) {
    $fileLocale = Get-TranslationLocaleCode -Locale ([string]$locale)
    if (!$fileLocale) {
      continue
    }

    $path = Join-Path $sourceRootResolved (Join-Path $Directory ($Prefix + $fileLocale + '.xtb'))
    if (!(Test-Path $path -PathType Leaf)) {
      throw "Missing translation bundle for supported locale ${locale}: $path"
    }

    $text = [IO.File]::ReadAllText($path)
    $pattern = '(?s)(<translation\s+id="([0-9]+)"[^>]*>)(.*?)(</translation>)'
    $updated = [regex]::Replace($text, $pattern, {
      param($match)
      $id = $match.Groups[2].Value
      $body = Replace-ProductBrandingInBody -Body $match.Groups[3].Value -TranslationId $id -PreserveChromiumProject $PreserveChromiumProject
      return $match.Groups[1].Value + $body + $match.Groups[4].Value
    })

    if ($updated -ne $text) {
      [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
      $updatedFiles++
    }
  }

  Write-Host "Updated $updatedFiles localized bundle(s) under $Directory"
}

Update-XtbBundle -Directory 'chrome/app/resources' -Prefix 'chromium_strings_' -PreserveChromiumProject $false
Update-XtbBundle -Directory 'components/strings' -Prefix 'components_chromium_strings_' -PreserveChromiumProject $true
Update-XtbBundle -Directory 'extensions/strings' -Prefix 'extensions_strings_' -PreserveChromiumProject $false

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source status after locale branding.'
}
if ($thirdPartyChanges) {
  throw 'Locale branding modified third_party sources; refusing to continue.'
}

& (Join-Path $PSScriptRoot 'verify-engine-locales.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium supported locale verification failed.'
}

Write-Host 'Ghosium supported locale branding applied and verified.'
