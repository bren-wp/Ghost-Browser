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
  throw "Refusing to rewrite product links in an unpinned checkout. Expected $expectedCommit; found $actualCommit"
}

function Replace-KnownLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue
  )

  $text = [IO.File]::ReadAllText($Path)
  if ($text.Contains($OldValue)) {
    $text = $text.Replace($OldValue, $NewValue)
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))
    return
  }
  if (!$text.Contains($NewValue)) {
    throw "Neither expected old nor new product-link literal was found in ${Path}: $OldValue"
  }
}

function Replace-KnownRegex {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement,
    [Parameter(Mandatory = $true)][string]$AlreadyPresent
  )

  $text = [IO.File]::ReadAllText($Path)
  if ([regex]::IsMatch($text, $Pattern)) {
    $text = [regex]::Replace($text, $Pattern, $Replacement, 1)
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))
    return
  }
  if (!$text.Contains($AlreadyPresent)) {
    throw "Expected product-link block was not found in $Path"
  }
}

$urlConstants = Join-Path $sourceRootResolved 'chrome/common/url_constants.h'
$customizeHandler = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/side_panel/customize_chrome/customize_chrome_page_handler.cc'
$chromePages = Join-Path $sourceRootResolved 'chrome/browser/ui/chrome_pages.cc'
$extensionsUi = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/extensions/extensions_ui.cc'
$aboutPageTs = Join-Path $sourceRootResolved 'chrome/browser/resources/settings/about_page/about_page.ts'

foreach ($path in @($urlConstants, $customizeHandler, $chromePages, $extensionsUi, $aboutPageTs)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Pinned source layout changed; product-link target is missing: $path"
  }
}

# Core Help entry points.
Replace-KnownLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=keyboard"' -NewValue '"https://ghosium.com/support"'
Replace-KnownLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=menu"' -NewValue '"https://ghosium.com/support"'
Replace-KnownLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=settings"' -NewValue '"https://ghosium.com/support"'

# New-tab Customize > Change theme. Keep the Chromium Web Store security model
# untouched; only the user-facing navigation target is changed here.
Replace-KnownLiteral -Path $customizeHandler -OldValue 'GURL("https://chromewebstore.google.com/category/themes")' -NewValue 'GURL("https://store.ghosium.com/")'

# App menu / extensions menu Store navigation. Do not repoint
# extension_urls::GetNewWebstoreLaunchURL(), because that URL participates in
# origin/CORS/site-isolation decisions. Ghosium Store gets its own trust model.
Replace-KnownLiteral -Path $chromePages -OldValue 'GURL webstore_url = extension_urls::GetNewWebstoreLaunchURL();' -NewValue 'GURL webstore_url("https://store.ghosium.com/");'
Replace-KnownLiteral -Path $chromePages -OldValue 'browser, extension_urls::AppendUtmSource(webstore_url, utm_source_value));' -NewValue 'browser, webstore_url);'

# chrome://extensions user-facing links. These are navigation/help strings only;
# they do not grant store privileges or change extension origin checks.
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"suspiciousInstallHelpUrl",\s*base::ASCIIToUTF16\(google_util::AppendGoogleLocaleParam\(\s*GURL\(chrome::kRemoveNonCWSExtensionURL\),\s*g_browser_process->GetApplicationLocale\(\)\)\s*\.spec\(\)\)\);' -Replacement 'source->AddString("suspiciousInstallHelpUrl",`n                    base::ASCIIToUTF16("https://ghosium.com/security"));' -AlreadyPresent 'https://ghosium.com/security'
Replace-KnownLiteral -Path $extensionsUi -OldValue 'source->AddString("enhancedSafeBrowsingWarningHelpUrl",`n                    chrome::kCwsEnhancedSafeBrowsingLearnMoreURL);' -NewValue 'source->AddString("enhancedSafeBrowsingWarningHelpUrl",`n                    "https://ghosium.com/security");'
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"getMoreExtensionsUrl",\s*base::ASCIIToUTF16\(\s*google_util::AppendGoogleLocaleParam\(\s*extension_urls::AppendUtmSource\(\s*extension_urls::GetWebstoreExtensionsCategoryURL\(\),\s*extension_urls::kExtensionsSidebarUtmSource\),\s*g_browser_process->GetApplicationLocale\(\)\)\s*\.spec\(\)\)\);' -Replacement 'source->AddString("getMoreExtensionsUrl",`n                    base::ASCIIToUTF16("https://store.ghosium.com/"));' -AlreadyPresent 'https://store.ghosium.com/'
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"modernWebGuidanceURL",\s*base::ASCIIToUTF16\(google_util::AppendGoogleLocaleParam\(\s*extension_urls::AppendUtmSource\(\s*extension_urls::GetModernWebGuidanceURL\(\),\s*extension_urls::kExtensionsSidebarUtmSource\),\s*g_browser_process->GetApplicationLocale\(\)\)\s*\.spec\(\)\)\);' -Replacement 'source->AddString("modernWebGuidanceURL",`n                    base::ASCIIToUTF16("https://ghosium.com/support"));' -AlreadyPresent 'https://ghosium.com/support'
Replace-KnownLiteral -Path $extensionsUi -OldValue 'source->AddString(`n      "hostPermissionsLearnMoreLink",`n      extension_permissions_constants::kRuntimeHostPermissionsHelpURL);' -NewValue 'source->AddString("hostPermissionsLearnMoreLink",`n                    "https://ghosium.com/support");'

# About privacy URL for builds that expose the row.
Replace-KnownLiteral -Path $aboutPageTs -OldValue "'https://policies.google.com/privacy'" -NewValue "'https://ghosium.com/legal/privacy-policy'"

$modifiedProductLinkFiles = @($urlConstants, $customizeHandler, $chromePages, $extensionsUi, $aboutPageTs)
$approved = @($config.allowedProductUrls)
foreach ($path in $modifiedProductLinkFiles) {
  $text = [IO.File]::ReadAllText($path)
  $ghosiumUrls = [regex]::Matches($text, 'https://(?:[a-z0-9-]+\.)?ghosium\.com[^"''\s<>)\]]*') |
      ForEach-Object Value | Sort-Object -Unique
  foreach ($url in $ghosiumUrls) {
    if ($approved -notcontains $url) {
      throw "Product-generated URL is outside the approved Ghosium allowlist in ${Path}: $url"
    }
  }
}

foreach ($legacy in @(
  'https://chromewebstore.google.com/category/themes',
  'https://policies.google.com/privacy'
)) {
  foreach ($path in $modifiedProductLinkFiles) {
    if ([IO.File]::ReadAllText($path).Contains($legacy)) {
      throw "Legacy product-generated URL remains in ${Path}: $legacy"
    }
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party status after product-link routing.'
}
if ($thirdPartyChanges) {
  throw 'Product-link routing modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium first-party product link routing: OK'
