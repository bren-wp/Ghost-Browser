param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$OutDir = 'out/Ghosium',

  [Parameter(Mandatory = $false)]
  [string]$ProvenancePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$ghosiumVersion = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path
$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Build output does not originate from pinned Chromium source $expectedRevision"
}

$outPath = if ([IO.Path]::IsPathRooted($OutDir)) {
  [IO.Path]::GetFullPath($OutDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $sourceRootResolved $OutDir))
}
if (!(Test-Path $outPath -PathType Container)) {
  throw "Ghosium build output directory does not exist: $outPath"
}

$requiredFiles = @(
  'args.gn',
  'chrome.exe',
  'chrome.dll',
  'chrome_elf.dll',
  'locales/en-US.pak',
  'setup.exe',
  'mini_installer.exe',
  'chrome.7z'
)
foreach ($relative in $requiredFiles) {
  $path = Join-Path $outPath $relative
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required full-source build artifact is missing: $relative"
  }
  if ((Get-Item $path).Length -le 0) {
    throw "Full-source build artifact is empty: $relative"
  }
}

$chrome = Get-Item (Join-Path $outPath 'chrome.exe')
$chromeInfo = $chrome.VersionInfo
if ([string]$chromeInfo.ProductName -ne 'Ghosium Browser') {
  throw "chrome.exe ProductName is not Ghosium Browser: '$($chromeInfo.ProductName)'"
}
if ([string]$chromeInfo.CompanyName -ne 'Brendigo') {
  throw "chrome.exe CompanyName is not Brendigo: '$($chromeInfo.CompanyName)'"
}
if (!$chromeInfo.ProductVersion) {
  throw 'chrome.exe ProductVersion is empty.'
}

$installer = Get-Item (Join-Path $outPath 'mini_installer.exe')
$installerInfo = $installer.VersionInfo
if ($installerInfo.ProductName -and [string]$installerInfo.ProductName -notmatch 'Ghosium') {
  throw "mini_installer.exe exposes unexpected ProductName: '$($installerInfo.ProductName)'"
}

$argsText = [IO.File]::ReadAllText((Join-Path $outPath 'args.gn'))
foreach ($required in @(
  'is_debug = false',
  'is_component_build = false',
  'is_official_build = false',
  'is_chrome_branded = false',
  'target_cpu = "x64"',
  'use_remoteexec = false'
)) {
  if (!$argsText.Contains($required)) {
    throw "Generated args.gn lost required Ghosium invariant: $required"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state for built engine.'
}
if ($thirdPartyChanges) {
  throw 'Full-source build verification detected modified third_party sources.'
}

$filesToHash = @(
  'chrome.exe',
  'chrome.dll',
  'chrome_elf.dll',
  'setup.exe',
  'mini_installer.exe',
  'chrome.7z',
  'args.gn'
)
$hashes = [ordered]@{}
foreach ($relative in $filesToHash) {
  $hashes[$relative] = (Get-FileHash (Join-Path $outPath $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
}

if (!$ProvenancePath) {
  $ProvenancePath = Join-Path $outPath 'GHOSIUM-SOURCE-BUILD.json'
} elseif (![IO.Path]::IsPathRooted($ProvenancePath)) {
  $ProvenancePath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $ProvenancePath))
}

$provenance = [ordered]@{
  product = 'Ghosium Browser'
  ghosiumVersion = $ghosiumVersion
  architecture = 'windows-x64'
  engineSourceRevision = $expectedRevision
  engineProductVersion = [string]$chromeInfo.ProductVersion
  publisher = [string]$chromeInfo.CompanyName
  chromeProductName = [string]$chromeInfo.ProductName
  installerProductName = [string]$installerInfo.ProductName
  repositoryCommit = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { $null }
  verifiedUtc = [DateTime]::UtcNow.ToString('o')
  sha256 = $hashes
}
$provenance | ConvertTo-Json -Depth 5 | Set-Content $ProvenancePath -Encoding utf8

Write-Host "Ghosium full-source Windows binary verification: OK"
Write-Host "Engine version: $($chromeInfo.ProductVersion)"
Write-Host "Provenance: $ProvenancePath"
