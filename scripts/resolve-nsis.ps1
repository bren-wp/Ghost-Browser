param(
  [string]$Destination = (Join-Path $env:RUNNER_TEMP 'ghosium-nsis')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedVersion = 'v3.12'
$archiveUrl = 'https://downloads.sourceforge.net/project/nsis/NSIS%203/3.12/nsis-3.12.zip'
$archiveSha256 = '56581f90db321581c5381193d796fffcf2d24b2f8fed2160a6c6a3baa67f2c4f'

function Test-Makensis {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (!(Test-Path $Path -PathType Leaf)) {
    return $false
  }

  try {
    $version = (& $Path /VERSION 2>$null | Select-Object -First 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -ne $expectedVersion) {
      Write-Host "Ignoring unexpected makensis at $Path; version='$version'"
      return $false
    }
    return $true
  } catch {
    return $false
  }
}

function Find-Makensis {
  $command = Get-Command makensis.exe -ErrorAction SilentlyContinue
  if ($command -and (Test-Makensis -Path $command.Source)) {
    return $command.Source
  }

  foreach ($candidate in @(
    'C:\Program Files (x86)\NSIS\makensis.exe',
    'C:\Program Files\NSIS\makensis.exe'
  )) {
    if (Test-Makensis -Path $candidate) {
      return $candidate
    }
  }

  return $null
}

$existing = Find-Makensis
if ($existing) {
  Write-Host "Using existing verified NSIS $expectedVersion: $existing"
  Write-Output $existing
  exit 0
}

Write-Host 'No verified NSIS 3.12 installation found; using pinned official portable archive.'
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$archive = Join-Path $Destination 'nsis-3.12.zip'
$extractRoot = Join-Path $Destination 'extract'
if (Test-Path $extractRoot) {
  Remove-Item $extractRoot -Recurse -Force
}

& curl.exe --fail --silent --show-error --location --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 20 $archiveUrl --output $archive
if ($LASTEXITCODE -ne 0 -or !(Test-Path $archive -PathType Leaf)) {
  throw 'Unable to download the official NSIS 3.12 portable archive.'
}

$archiveItem = Get-Item $archive
if ($archiveItem.Length -lt 1MB -or $archiveItem.Length -gt 10MB) {
  throw "Downloaded NSIS archive size is outside the expected range: $($archiveItem.Length) bytes"
}

$actualSha256 = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if (![string]::Equals($actualSha256, $archiveSha256, [StringComparison]::Ordinal)) {
  throw "NSIS archive SHA-256 mismatch. Expected $archiveSha256; found $actualSha256"
}

Expand-Archive -Path $archive -DestinationPath $extractRoot -Force
$fallback = Join-Path $extractRoot 'nsis-3.12\bin\makensis.exe'
if (!(Test-Makensis -Path $fallback)) {
  throw 'Verified NSIS archive did not provide makensis v3.12.'
}

Write-Host "Verified official NSIS portable toolchain: $fallback"
Write-Output $fallback
