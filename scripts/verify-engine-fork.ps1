param(
  [Parameter(Mandatory = $false)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot 'engine/branding/product.json'
$sourceRevisionPath = Join-Path $repoRoot 'ENGINE_SOURCE_REVISION'
$snapshotRevisionPath = Join-Path $repoRoot 'ENGINE_REVISION'
$thirdPartyNoticesPath = Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md'

foreach ($required in @($configPath, $sourceRevisionPath, $snapshotRevisionPath, $thirdPartyNoticesPath)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Required Ghosium fork file is missing: $required"
  }
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$sourceRevision = (Get-Content $sourceRevisionPath -Raw).Trim()
$snapshotRevision = (Get-Content $snapshotRevisionPath -Raw).Trim()

if ($sourceRevision -notmatch '^[0-9a-f]{40}$') {
  throw 'ENGINE_SOURCE_REVISION must be a pinned 40-character lowercase Git commit.'
}
if ($snapshotRevision -notmatch '^\d+$') {
  throw 'ENGINE_REVISION must remain a pinned numeric snapshot revision.'
}
if ($config.source.commit -ne $sourceRevision) {
  throw 'engine/branding/product.json source.commit does not match ENGINE_SOURCE_REVISION.'
}
if ([string]$config.source.snapshotRevision -ne $snapshotRevision) {
  throw 'engine/branding/product.json source.snapshotRevision does not match ENGINE_REVISION.'
}

if ($config.product.name -ne 'Ghosium Browser' -or $config.product.shortName -ne 'Ghosium') {
  throw 'Product branding contract must use Ghosium Browser / Ghosium.'
}
if ($config.product.publisher -ne 'Brendigo' -or $config.product.windowsCompanyName -ne 'Brendigo') {
  throw 'Publisher metadata must remain Brendigo.'
}

$expectedUrls = @(
  'https://ghosium.com/',
  'https://search.ghosium.com/',
  'https://store.ghosium.com/',
  'https://ghosium.com/legal/terms',
  'https://ghosium.com/legal/privacy-policy',
  'https://ghosium.com/legal/licenses',
  'https://ghosium.com/support',
  'https://ghosium.com/security'
)
$actualUrls = @($config.allowedProductUrls)
if ($actualUrls.Count -ne $expectedUrls.Count) {
  throw "Ghosium product URL allowlist must contain exactly $($expectedUrls.Count) entries."
}
if (@($actualUrls | Sort-Object -Unique).Count -ne $actualUrls.Count) {
  throw 'Ghosium product URL allowlist contains duplicate entries.'
}
foreach ($url in $expectedUrls) {
  if ($actualUrls -notcontains $url) {
    throw "Missing required Ghosium product URL: $url"
  }
}
foreach ($property in $config.productUrls.PSObject.Properties) {
  if ($actualUrls -notcontains [string]$property.Value) {
    throw "Product-generated URL is outside the approved allowlist: $($property.Value)"
  }
}

$locales = @($config.locales.supported)
if ($locales.Count -ne 30) {
  throw "Ghosium must define exactly 30 supported locales; found $($locales.Count)."
}
if (@($locales | Sort-Object -Unique).Count -ne 30) {
  throw 'Ghosium locale list contains duplicates.'
}
if ($config.locales.default -ne 'en-US') {
  throw 'English en-US must remain the default locale.'
}
if ($config.locales.required -ne 'hr' -or $locales -notcontains 'hr') {
  throw 'Croatian hr must remain a required supported locale.'
}
if ($locales -notcontains 'en-US') {
  throw 'The supported locale set must contain en-US.'
}

if (!$config.legal.preserveThirdPartyLicenses -or !$config.legal.preserveCopyrightNotices -or !$config.legal.preserveAttribution) {
  throw 'Third-party legal preservation invariants must remain enabled.'
}
if ([string]$config.legal.thirdPartySurface -ne 'legal/third-party') {
  throw 'Third-party attribution must remain isolated under legal/third-party.'
}

foreach ($securityInvariant in @('sandbox', 'processIsolation', 'certificateValidation', 'extensionSignatureVerification', 'updateSignatureVerification')) {
  if ([string]$config.securityInvariants.$securityInvariant -ne 'required') {
    throw "Security invariant must remain required: $securityInvariant"
  }
}

if ($SourceRoot) {
  $resolvedSourceRoot = (Resolve-Path $SourceRoot).Path
  $gitDirectory = Join-Path $resolvedSourceRoot '.git'
  if (!(Test-Path $gitDirectory)) {
    throw "SourceRoot is not a Chromium Git checkout: $resolvedSourceRoot"
  }

  $actualCommit = (& git -C $resolvedSourceRoot rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $sourceRevision) {
    throw "Chromium checkout must be detached at $sourceRevision; found $actualCommit"
  }

  $requiredEngineFiles = @(
    'chrome/app/chromium_strings.grd',
    'chrome/app/settings_chromium_strings.grdp',
    'chrome/common/url_constants.h'
  )
  foreach ($relativePath in $requiredEngineFiles) {
    if (!(Test-Path (Join-Path $resolvedSourceRoot $relativePath) -PathType Leaf)) {
      throw "Pinned engine source is missing expected file: $relativePath"
    }
  }

  $productStrings = Get-Content (Join-Path $resolvedSourceRoot 'chrome/app/chromium_strings.grd') -Raw
  foreach ($needle in @('Ghosium Browser', 'Ghosium')) {
    if (!$productStrings.Contains($needle)) {
      throw "Applied engine branding is missing expected product string: $needle"
    }
  }

  $settingsStrings = Get-Content (Join-Path $resolvedSourceRoot 'chrome/app/settings_chromium_strings.grdp') -Raw
  if (!$settingsStrings.Contains('About Ghosium Browser')) {
    throw 'About surface is not Ghosium branded.'
  }
  if (!$settingsStrings.Contains('Ghosium Support')) {
    throw 'Settings help surface is not routed as Ghosium Support.'
  }

  $urlConstants = Get-Content (Join-Path $resolvedSourceRoot 'chrome/common/url_constants.h') -Raw
  foreach ($requiredUrl in @('https://ghosium.com/support')) {
    if (!$urlConstants.Contains($requiredUrl)) {
      throw "Engine product URL routing is missing required URL: $requiredUrl"
    }
  }

  $status = & git -C $resolvedSourceRoot status --porcelain=v1 -- third_party
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify third_party source status.'
  }
  if ($status) {
    throw 'Ghosium branding automation must not modify Chromium third_party sources.'
  }
}

Write-Host 'Ghosium full-source engine fork contract: OK'
