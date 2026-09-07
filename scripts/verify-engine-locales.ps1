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

function Get-TranslationLocaleCode {
  param([Parameter(Mandatory = $true)][string]$Locale)

  switch ($Locale) {
    'en-US' { return $null }
    'nb' { return 'no' }
    'he' { return 'iw' }
    default { return $Locale }
  }
}

function Test-LegacyBrowserBrand {
  param([Parameter(Mandatory = $true)][string]$Text)

  # Detect standalone names and grammatical lowercase suffixes such as
  # Chromiuma/Chromiumu while avoiding unrelated uppercase compounds such as
  # ChromiumOS/ChromeOS, which are separate upstream platform names. PowerShell
  # -match is case-insensitive by default, so use -cmatch here; only the Google
  # Chrome phrase gets an explicit scoped case-insensitive modifier.
  return $Text -cmatch '(?i:\bGoogle Chrome\b)|\bChromium(?=\p{Ll}|\b)|\bChrome(?=\p{Ll}|\b)'
}

function Assert-XtbBundleBranding {
  param(
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][bool]$AllowLegalChromiumProject
  )

  $checked = 0
  foreach ($locale in @($config.locales.supported)) {
    $fileLocale = Get-TranslationLocaleCode -Locale ([string]$locale)
    if (!$fileLocale) {
      continue
    }

    $path = Join-Path $sourceRootResolved (Join-Path $Directory ($Prefix + $fileLocale + '.xtb'))
    if (!(Test-Path $path -PathType Leaf)) {
      throw "Missing Ghosium translation bundle for supported locale ${locale}: $path"
    }

    $text = [IO.File]::ReadAllText($path)
    $translations = [regex]::Matches($text, '(?s)<translation\s+id="([0-9]+)"[^>]*>(.*?)</translation>')
    foreach ($translation in $translations) {
      $id = $translation.Groups[1].Value
      $body = [System.Net.WebUtility]::HtmlDecode($translation.Groups[2].Value)

      if ($AllowLegalChromiumProject -and $legalChromiumIds -contains $id) {
        if (!$body.Contains('Ghosium Browser') -or !$body.Contains('Chromium')) {
          throw "Legal upstream attribution is malformed in locale ${locale}, translation $id"
        }
        continue
      }

      if (Test-LegacyBrowserBrand -Text $body) {
        throw "Legacy Chromium/Chrome product branding remains in locale ${locale}: $path (translation $id)"
      }
    }

    $checked++
  }

  if ($checked -ne 29) {
    throw "Expected 29 translated bundles plus en-US source; checked $checked under $Directory"
  }
  Write-Host "Verified $checked localized bundle(s) under $Directory"
}

Assert-XtbBundleBranding -Directory 'chrome/app/resources' -Prefix 'chromium_strings_' -AllowLegalChromiumProject $false
Assert-XtbBundleBranding -Directory 'components/strings' -Prefix 'components_chromium_strings_' -AllowLegalChromiumProject $true
Assert-XtbBundleBranding -Directory 'extensions/strings' -Prefix 'extensions_strings_' -AllowLegalChromiumProject $false

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source status during locale audit.'
}
if ($thirdPartyChanges) {
  throw 'Locale audit detected third_party modifications.'
}

Write-Host 'Ghosium 30-locale branding audit: OK'
