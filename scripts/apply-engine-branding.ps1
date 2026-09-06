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

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue
  )

  $text = [IO.File]::ReadAllText($Path)
  if (!$text.Contains($OldValue)) {
    throw "Expected source literal was not found in $Path: $OldValue"
  }
  $updated = $text.Replace($OldValue, $NewValue)
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
}

$chromiumStrings = Join-Path $sourceRootResolved 'chrome/app/chromium_strings.grd'
$settingsStrings = Join-Path $sourceRootResolved 'chrome/app/settings_chromium_strings.grdp'
$urlConstants = Join-Path $sourceRootResolved 'chrome/common/url_constants.h'

foreach ($required in @($chromiumStrings, $settingsStrings, $urlConstants)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Pinned source layout changed; expected file missing: $required"
  }
}

Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_PRODUCT_NAME' -Value $config.product.name
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_SHORT_PRODUCT_NAME' -Value $config.product.shortName
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_PRODUCT_DESCRIPTION' -Value $config.product.description
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_WELCOME_TO_CHROME' -Value 'Welcome to Ghosium Browser; new browser window opened'

Set-GritMessage -Path $settingsStrings -MessageId 'IDS_RELAUNCH_CONFIRMATION_DIALOG_TITLE' -Value 'Relaunch Ghosium Browser?'
Set-GritMessage -Path $settingsStrings -MessageId 'IDS_SETTINGS_ABOUT_PROGRAM' -Value 'About Ghosium Browser'
Set-GritMessage -Path $settingsStrings -MessageId 'IDS_SETTINGS_GET_HELP_USING_CHROME' -Value 'Ghosium Support'

Replace-RequiredLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=keyboard"' -NewValue '"https://ghosium.com/support"'
Replace-RequiredLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=menu"' -NewValue '"https://ghosium.com/support"'
Replace-RequiredLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=settings"' -NewValue '"https://ghosium.com/support"'

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

Write-Host 'Initial source-level Ghosium branding applied successfully.'
