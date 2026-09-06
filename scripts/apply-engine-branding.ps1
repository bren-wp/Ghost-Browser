param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $repoRoot 'engine/branding/product.json') -Raw | ConvertFrom-Json
$expectedCommit = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualCommit = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $expectedCommit) {
  throw "Refusing to brand an unpinned checkout. Expected $expectedCommit; found $actualCommit"
}

function Set-GritMessage {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$MessageId,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $text = [IO.File]::ReadAllText($Path)
  $escapedId = [regex]::Escape($MessageId)
  $pattern = '(?s)(<message\s+[^>]*name="' + $escapedId + '"[^>]*>)(.*?)(</message>)'
  $matches = [regex]::Matches($text, $pattern)
  if ($matches.Count -lt 1) {
    throw "Expected GRIT message was not found: $MessageId in $Path"
  }

  $replacement = { param($match) $match.Groups[1].Value + "`n      " + $Value + "`n    " + $match.Groups[3].Value }
  $updated = [regex]::Replace($text, $pattern, $replacement)
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
  Write-Host "Updated $MessageId ($($matches.Count) occurrence(s))"
}

function Replace-GritProductBranding {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $text = [IO.File]::ReadAllText($Path)
  $pattern = '(?s)(<message\b[^>]*>)(.*?)(</message>)'
  $updated = [regex]::Replace($text, $pattern, {
    param($match)
    $body = $match.Groups[2].Value
    $body = $body.Replace('Chrome Web Store', 'Ghosium Store')
    $body = $body.Replace('Google Chrome for Testing', 'Ghosium Browser')
    $body = $body.Replace('Chrome for Testing', 'Ghosium Browser')
    $body = $body.Replace('Google Chrome', 'Ghosium Browser')
    $body = [regex]::Replace($body, '\bChromium\b', 'Ghosium Browser')
    $body = [regex]::Replace($body, '\bChrome\b', 'Ghosium Browser')
    $body = $body.Replace('Ghosium Browser browser', 'Ghosium Browser')
    return $match.Groups[1].Value + $body + $match.Groups[3].Value
  })
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
}

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue
  )

  $text = [IO.File]::ReadAllText($Path)
  if (!$text.Contains($OldValue)) {
    throw "Expected source literal was not found in ${Path}: $OldValue"
  }
  $updated = $text.Replace($OldValue, $NewValue)
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
}

function Set-BrandingValue {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Key,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $text = [IO.File]::ReadAllText($Path)
  $pattern = '(?m)^' + [regex]::Escape($Key) + '=.*$'
  if (![regex]::IsMatch($text, $pattern)) {
    throw "Expected branding key was not found: $Key"
  }
  $updated = [regex]::Replace($text, $pattern, $Key + '=' + $Value)
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
}

$chromiumStrings = Join-Path $sourceRootResolved 'chrome/app/chromium_strings.grd'
$settingsStrings = Join-Path $sourceRootResolved 'chrome/app/settings_chromium_strings.grdp'
$componentStrings = Join-Path $sourceRootResolved 'components/components_chromium_strings.grd'
$extensionStrings = Join-Path $sourceRootResolved 'extensions/strings/extensions_chromium_strings.grdp'
$urlConstants = Join-Path $sourceRootResolved 'chrome/common/url_constants.h'
$brandingFile = Join-Path $sourceRootResolved 'chrome/app/theme/chromium/BRANDING'

foreach ($required in @(
  $chromiumStrings,
  $settingsStrings,
  $componentStrings,
  $extensionStrings,
  $urlConstants,
  $brandingFile
)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Pinned source layout changed; expected file missing: $required"
  }
}

# Replace product branding only inside GRIT message bodies. XML comments,
# descriptions, source-code copyright headers and third-party trees stay intact.
foreach ($path in @($chromiumStrings, $settingsStrings, $componentStrings, $extensionStrings)) {
  Replace-GritProductBranding -Path $path
}

Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_PRODUCT_NAME' -Value $config.product.name
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_SHORT_PRODUCT_NAME' -Value $config.product.shortName
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_PRODUCT_DESCRIPTION' -Value $config.product.description
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_WELCOME_TO_CHROME' -Value 'Welcome to Ghosium Browser; new browser window opened'

Set-GritMessage -Path $settingsStrings -MessageId 'IDS_RELAUNCH_CONFIRMATION_DIALOG_TITLE' -Value 'Relaunch Ghosium Browser?'
Set-GritMessage -Path $settingsStrings -MessageId 'IDS_SETTINGS_ABOUT_PROGRAM' -Value 'About Ghosium Browser'
Set-GritMessage -Path $settingsStrings -MessageId 'IDS_SETTINGS_GET_HELP_USING_CHROME' -Value 'Ghosium Support'

Set-GritMessage -Path $componentStrings -MessageId 'IDS_SHORT_PRODUCT_LOGO_ALT_TEXT' -Value 'Ghosium logo'

# These two messages are legal attribution, not Ghosium product branding. Keep
# Chromium named here as the upstream open-source project while making it clear
# that Ghosium Browser is the product the user is running.
$legalLicense = 'Ghosium Browser is built with the <ph name="BEGIN_LINK_CHROMIUM">&lt;a target="_blank" href="$1" aria-description="$3"&gt;</ph>Chromium<ph name="END_LINK_CHROMIUM">&lt;/a&gt;</ph> open-source project and other <ph name="BEGIN_LINK_OSS">&lt;a target="_blank" href="$2" aria-description="$3"&gt;</ph>open-source software<ph name="END_LINK_OSS">&lt;/a&gt;</ph>.'
$legalChromium = 'Ghosium Browser is built with the <ph name="BEGIN_LINK_CHROMIUM">&lt;a target="_blank" href="$1"&gt;</ph>Chromium<ph name="END_LINK_CHROMIUM">&lt;/a&gt;</ph> open-source project.'
Set-GritMessage -Path $componentStrings -MessageId 'IDS_VERSION_UI_LICENSE' -Value $legalLicense
Set-GritMessage -Path $componentStrings -MessageId 'IDS_VERSION_UI_LICENSE_CHROMIUM' -Value $legalChromium

# Windows file metadata and product identity are sourced from Chromium BRANDING.
Set-BrandingValue -Path $brandingFile -Key 'COMPANY_FULLNAME' -Value 'Brendigo'
Set-BrandingValue -Path $brandingFile -Key 'COMPANY_SHORTNAME' -Value 'Brendigo'
Set-BrandingValue -Path $brandingFile -Key 'PRODUCT_FULLNAME' -Value 'Ghosium Browser'
Set-BrandingValue -Path $brandingFile -Key 'PRODUCT_SHORTNAME' -Value 'Ghosium'
Set-BrandingValue -Path $brandingFile -Key 'PRODUCT_INSTALLER_FULLNAME' -Value 'Ghosium Browser Installer'
Set-BrandingValue -Path $brandingFile -Key 'PRODUCT_INSTALLER_SHORTNAME' -Value 'Ghosium Installer'
Set-BrandingValue -Path $brandingFile -Key 'COPYRIGHT' -Value 'Copyright @LASTCHANGE_YEAR@ Brendigo. Chromium and third-party components retain their respective copyrights.'
Set-BrandingValue -Path $brandingFile -Key 'MAC_BUNDLE_ID' -Value 'com.brendigo.ghosium'
Set-BrandingValue -Path $brandingFile -Key 'MAC_CREATOR_CODE' -Value 'Gh24'

# Product-generated Help entry points must stay on Ghosium-controlled domains.
Replace-RequiredLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=keyboard"' -NewValue '"https://ghosium.com/support"'
Replace-RequiredLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=menu"' -NewValue '"https://ghosium.com/support"'
Replace-RequiredLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=settings"' -NewValue '"https://ghosium.com/support"'

& (Join-Path $PSScriptRoot 'rewrite-engine-product-links.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium first-party product link routing failed.'
}

# Replace every product icon path used by current-channel-logo, Windows resources,
# tiles, app shortcuts and product vector icons.
$brandSvg = Join-Path $repoRoot 'engine/branding/ghosium-mark.svg'
$vectorIcon = Join-Path $repoRoot 'engine/branding/vector/product.icon'
$vectorRefreshIcon = Join-Path $repoRoot 'engine/branding/vector/product_refresh.icon'
foreach ($asset in @($brandSvg, $vectorIcon, $vectorRefreshIcon)) {
  if (!(Test-Path $asset -PathType Leaf)) {
    throw "Required Ghosium brand asset is missing: $asset"
  }
}

Copy-Item $brandSvg (Join-Path $sourceRootResolved 'chrome/app/theme/chromium/product_logo.svg') -Force
Copy-Item $vectorIcon (Join-Path $sourceRootResolved 'components/vector_icons/chromium/product.icon') -Force
Copy-Item $vectorRefreshIcon (Join-Path $sourceRootResolved 'components/vector_icons/chromium/product_refresh.icon') -Force

$python = Get-Command python -ErrorAction SilentlyContinue
if (!$python) {
  $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (!$python) {
  throw 'Python 3 is required to generate deterministic Ghosium PNG/ICO engine assets.'
}
& $python.Source (Join-Path $repoRoot 'scripts/generate-engine-brand-assets.py') $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw "Ghosium engine asset generation failed with exit code $LASTEXITCODE"
}

& (Join-Path $PSScriptRoot 'rebrand-engine-locales.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium supported locale branding failed.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source status after branding.'
}
if ($thirdPartyChanges) {
  throw 'Branding operation modified third_party sources; refusing to continue.'
}

& (Join-Path $PSScriptRoot 'verify-engine-fork.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium full-source verification failed after branding.'
}

Write-Host 'Source-level Ghosium branding, first-party links, locale strings and product icons applied successfully.'
