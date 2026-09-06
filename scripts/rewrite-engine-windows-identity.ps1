param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Refusing to rewrite Windows identity on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$target = Join-Path $sourceRootResolved 'chrome/install_static/chromium_install_modes.h'
if (!(Test-Path $target -PathType Leaf)) {
  throw "Pinned Chromium Windows install-mode source is missing: $target"
}

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue
  )

  if ($Text.Contains($NewValue)) {
    return $Text
  }
  if (!$Text.Contains($OldValue)) {
    throw "Pinned Chromium Windows identity changed; missing expected literal: $OldValue"
  }
  return $Text.Replace($OldValue, $NewValue)
}

$text = [IO.File]::ReadAllText($target)
$updated = $text

# Keep upstream internal enum/type names intact, but replace values that escape
# into install paths, Default Programs, registry ProgIDs and direct-launch URLs.
$updated = Replace-RequiredLiteral -Text $updated -OldValue 'inline constexpr wchar_t kCompanyPathName[] = L"";' -NewValue 'inline constexpr wchar_t kCompanyPathName[] = L"Brendigo";'
$updated = Replace-RequiredLiteral -Text $updated -OldValue 'inline constexpr wchar_t kProductPathName[] = L"Chromium";' -NewValue 'inline constexpr wchar_t kProductPathName[] = L"Ghosium";'
$updated = Replace-RequiredLiteral -Text $updated -OldValue '.base_app_name = L"Chromium",' -NewValue '.base_app_name = L"Ghosium Browser",'
$updated = Replace-RequiredLiteral -Text $updated -OldValue '.base_app_id = L"Chromium",' -NewValue '.base_app_id = L"Ghosium",'
$updated = Replace-RequiredLiteral -Text $updated -OldValue '.browser_prog_id_prefix = L"ChromiumHTM",' -NewValue '.browser_prog_id_prefix = L"GhosiumHTM",'
$updated = Replace-RequiredLiteral -Text $updated -OldValue 'L"Chromium HTML Document",' -NewValue 'L"Ghosium HTML Document",'
$updated = Replace-RequiredLiteral -Text $updated -OldValue '.direct_launch_url_scheme = "chromium",' -NewValue '.direct_launch_url_scheme = "ghosium",'
$updated = Replace-RequiredLiteral -Text $updated -OldValue '.pdf_prog_id_prefix = L"ChromiumPDF",' -NewValue '.pdf_prog_id_prefix = L"GhosiumPDF",'
$updated = Replace-RequiredLiteral -Text $updated -OldValue 'L"Chromium PDF Document",' -NewValue 'L"Ghosium PDF Document",'

if ($updated -ne $text) {
  [IO.File]::WriteAllText($target, $updated, [Text.UTF8Encoding]::new($false))
  Write-Host 'Ghosium Windows install/registry identity applied.'
} else {
  Write-Host 'Ghosium Windows install/registry identity is already applied.'
}

$verify = [IO.File]::ReadAllText($target)
foreach ($required in @(
  'kCompanyPathName[] = L"Brendigo"',
  'kProductPathName[] = L"Ghosium"',
  '.base_app_name = L"Ghosium Browser"',
  '.base_app_id = L"Ghosium"',
  '.browser_prog_id_prefix = L"GhosiumHTM"',
  'L"Ghosium HTML Document"',
  '.direct_launch_url_scheme = "ghosium"',
  '.pdf_prog_id_prefix = L"GhosiumPDF"',
  'L"Ghosium PDF Document"'
)) {
  if (!$verify.Contains($required)) {
    throw "Ghosium Windows identity verification failed: missing $required"
  }
}

foreach ($forbiddenVisible in @(
  'kProductPathName[] = L"Chromium"',
  '.base_app_name = L"Chromium"',
  '.base_app_id = L"Chromium"',
  '.browser_prog_id_prefix = L"ChromiumHTM"',
  'L"Chromium HTML Document"',
  '.direct_launch_url_scheme = "chromium"',
  '.pdf_prog_id_prefix = L"ChromiumPDF"',
  'L"Chromium PDF Document"'
)) {
  if ($verify.Contains($forbiddenVisible)) {
    throw "Legacy Chromium Windows product identity remains: $forbiddenVisible"
  }
}

# Safe Browsing client naming is an upstream security-service contract, not a
# user-visible Windows product identity. Do not casually rewrite it while
# security invariants require the upstream protection path to remain intact.
if (!$verify.Contains('kSafeBrowsingName[] = "chromium"')) {
  throw 'Safe Browsing client identity changed unexpectedly; review security integration before proceeding.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after Windows identity rewrite.'
}
if ($thirdPartyChanges) {
  throw 'Windows identity rewrite modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium Windows install identity: OK'
