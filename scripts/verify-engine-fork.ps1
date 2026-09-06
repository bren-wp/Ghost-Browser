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
$brandSvgPath = Join-Path $repoRoot 'engine/branding/ghosium-mark.svg'
$brandDarkSvgPath = Join-Path $repoRoot 'engine/branding/ghosium-mark-dark.svg'
$productVectorPath = Join-Path $repoRoot 'engine/branding/vector/product.icon'
$productRefreshVectorPath = Join-Path $repoRoot 'engine/branding/vector/product_refresh.icon'
$assetGeneratorPath = Join-Path $repoRoot 'scripts/generate-engine-brand-assets.py'

foreach ($required in @(
  $configPath,
  $sourceRevisionPath,
  $snapshotRevisionPath,
  $thirdPartyNoticesPath,
  $brandSvgPath,
  $brandDarkSvgPath,
  $productVectorPath,
  $productRefreshVectorPath,
  $assetGeneratorPath
)) {
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

function Assert-NoLegacyVisibleBrand {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $text = Get-Content $Path -Raw
  $messages = [regex]::Matches($text, '(?s)<message\b[^>]*>(.*?)</message>')
  foreach ($message in $messages) {
    $visible = [regex]::Replace($message.Groups[1].Value, '<[^>]+>', '')
    $visible = [System.Net.WebUtility]::HtmlDecode($visible)
    if ($visible -match '(?i)\bChromium\b|\bGoogle Chrome\b|\bChrome\b') {
      throw "Legacy browser branding remains in a user-visible GRIT message in $Path"
    }
  }
}

function Assert-FilePrefix {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][byte[]]$Prefix
  )

  if (!(Test-Path $Path -PathType Leaf)) {
    throw "Expected generated Ghosium asset is missing: $Path"
  }
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt $Prefix.Length) {
    throw "Generated Ghosium asset is unexpectedly small: $Path"
  }
  for ($i = 0; $i -lt $Prefix.Length; $i++) {
    if ($bytes[$i] -ne $Prefix[$i]) {
      throw "Generated Ghosium asset has an invalid file signature: $Path"
    }
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
    'chrome/common/url_constants.h',
    'chrome/app/theme/chromium/BRANDING',
    'chrome/app/theme/chromium/product_logo.svg',
    'chrome/browser/resources/contextual_tasks/top_toolbar_logo.html.ts',
    'chrome/browser/resources/signin/managed_user_profile_notice/managed_user_profile_notice_value_prop.html.ts',
    'ui/webui/resources/images/chrome_logo_dark.svg',
    'components/vector_icons/chromium/product.icon',
    'components/vector_icons/chromium/product_refresh.icon'
  )
  foreach ($relativePath in $requiredEngineFiles) {
    if (!(Test-Path (Join-Path $resolvedSourceRoot $relativePath) -PathType Leaf)) {
      throw "Pinned engine source is missing expected file: $relativePath"
    }
  }

  $productStringsPath = Join-Path $resolvedSourceRoot 'chrome/app/chromium_strings.grd'
  $settingsStringsPath = Join-Path $resolvedSourceRoot 'chrome/app/settings_chromium_strings.grdp'
  $productStrings = Get-Content $productStringsPath -Raw
  foreach ($needle in @('Ghosium Browser', 'Ghosium')) {
    if (!$productStrings.Contains($needle)) {
      throw "Applied engine branding is missing expected product string: $needle"
    }
  }
  if (!$productStrings.Contains('Customize Ghosium')) {
    throw 'Customize side-panel title is not Ghosium branded.'
  }
  Assert-NoLegacyVisibleBrand -Path $productStringsPath
  Assert-NoLegacyVisibleBrand -Path $settingsStringsPath

  $settingsStrings = Get-Content $settingsStringsPath -Raw
  if (!$settingsStrings.Contains('About Ghosium Browser')) {
    throw 'About surface is not Ghosium branded.'
  }
  if (!$settingsStrings.Contains('Ghosium Support')) {
    throw 'Settings help surface is not routed as Ghosium Support.'
  }

  $branding = Get-Content (Join-Path $resolvedSourceRoot 'chrome/app/theme/chromium/BRANDING') -Raw
  foreach ($requiredBrandingLine in @(
    'COMPANY_FULLNAME=Brendigo',
    'COMPANY_SHORTNAME=Brendigo',
    'PRODUCT_FULLNAME=Ghosium Browser',
    'PRODUCT_SHORTNAME=Ghosium',
    'PRODUCT_INSTALLER_FULLNAME=Ghosium Browser Installer',
    'PRODUCT_INSTALLER_SHORTNAME=Ghosium Installer',
    'MAC_BUNDLE_ID=com.brendigo.ghosium'
  )) {
    if (!$branding.Contains($requiredBrandingLine)) {
      throw "Engine BRANDING is missing required identity: $requiredBrandingLine"
    }
  }

  $urlConstants = Get-Content (Join-Path $resolvedSourceRoot 'chrome/common/url_constants.h') -Raw
  if (!$urlConstants.Contains('https://ghosium.com/support')) {
    throw 'Engine product URL routing is missing Ghosium Support.'
  }
  if ($urlConstants.Contains('https://support.google.com/chrome?p=help&ctx=')) {
    throw 'Legacy Chromium/Chrome Help URLs remain in Ghosium product routing.'
  }

  $productSvg = Get-Content (Join-Path $resolvedSourceRoot 'chrome/app/theme/chromium/product_logo.svg') -Raw
  if (!$productSvg.Contains('aria-label="Ghosium"') -or !$productSvg.Contains('#62E7D5')) {
    throw 'Chromium product_logo.svg was not replaced with the Ghosium mark.'
  }

  $darkLogo = Get-Content (Join-Path $resolvedSourceRoot 'ui/webui/resources/images/chrome_logo_dark.svg') -Raw
  if (!$darkLogo.Contains('aria-label="Ghosium"') -or !$darkLogo.Contains('#62E7D5')) {
    throw 'Shared dark-mode WebUI product logo was not replaced with Ghosium.'
  }

  $contextualToolbar = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/resources/contextual_tasks/top_toolbar_logo.html.ts') -Raw
  if ($contextualToolbar.Contains('chrome_product.svg') -or $contextualToolbar.Contains('chrome_logo_dark.svg')) {
    throw 'Contextual toolbar still references a legacy Chrome/Chromium product logo.'
  }
  if ([regex]::Matches($contextualToolbar, 'chrome://theme/current-channel-logo@2x').Count -lt 2) {
    throw 'Contextual toolbar is not consistently routed to the Ghosium current-channel logo.'
  }

  $managedProfile = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/resources/signin/managed_user_profile_notice/managed_user_profile_notice_value_prop.html.ts') -Raw
  if (!$managedProfile.Contains('alt="Ghosium logo"') -or $managedProfile.Contains('alt="Chrome logo"')) {
    throw 'Managed-profile product-logo accessibility text is not Ghosium branded.'
  }

  $productVector = Get-Content (Join-Path $resolvedSourceRoot 'components/vector_icons/chromium/product.icon') -Raw
  $productRefreshVector = Get-Content (Join-Path $resolvedSourceRoot 'components/vector_icons/chromium/product_refresh.icon') -Raw
  if (!$productVector.Contains('Ghosium product vector mark') -or !$productRefreshVector.Contains('Ghosium product vector mark')) {
    throw 'Chromium vector product icons were not replaced with Ghosium vectors.'
  }

  $pngSignature = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
  foreach ($relativePng in @(
    'chrome/app/theme/chromium/product_logo_16.png',
    'chrome/app/theme/chromium/product_logo_24.png',
    'chrome/app/theme/chromium/product_logo_32.png',
    'chrome/app/theme/chromium/product_logo_48.png',
    'chrome/app/theme/chromium/product_logo_64.png',
    'chrome/app/theme/chromium/product_logo_128.png',
    'chrome/app/theme/default_100_percent/chromium/product_logo_16.png',
    'chrome/app/theme/default_100_percent/chromium/product_logo_32.png',
    'chrome/app/theme/default_200_percent/chromium/product_logo_16.png',
    'chrome/app/theme/default_200_percent/chromium/product_logo_32.png',
    'chrome/app/theme/chromium/win/tiles/Logo.png',
    'chrome/app/theme/chromium/win/tiles/SmallLogo.png'
  )) {
    Assert-FilePrefix -Path (Join-Path $resolvedSourceRoot $relativePng) -Prefix $pngSignature
  }

  $icoSignature = [byte[]](0x00, 0x00, 0x01, 0x00)
  foreach ($relativeIco in @(
    'chrome/app/theme/chromium/win/chromium.ico',
    'chrome/app/theme/chromium/win/chromium_doc.ico',
    'chrome/app/theme/chromium/win/chromium_pdf.ico',
    'chrome/app/theme/chromium/win/app_list.ico',
    'chrome/app/theme/chromium/win/incognito.ico',
    'chrome/app/theme/chromium/win/isolated.ico'
  )) {
    Assert-FilePrefix -Path (Join-Path $resolvedSourceRoot $relativeIco) -Prefix $icoSignature
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
