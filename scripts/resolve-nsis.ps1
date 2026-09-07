param(
  [string]$Destination = (Join-Path $env:RUNNER_TEMP 'ghosium-nsis')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedVersion = 'v3.12'
$archiveUrl = 'https://downloads.sourceforge.net/project/nsis/NSIS%203/3.12/nsis-3.12.zip'
# Pinned NSIS 3.12 archive digest published by the Scoop package manifest.
$archiveSha1 = '364fd795b0cafc1fbff3e966f103a8f8fc8fb7f1'

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
  Write-Host "Using existing NSIS $expectedVersion: $existing"
  Write-Output $existing
  exit 0
}

$choco = Get-Command choco.exe -ErrorAction SilentlyContinue
if ($choco) {
  $delays = @(5, 15, 30)
  for ($attempt = 0; $attempt -lt $delays.Count; $attempt++) {
    Write-Host "Installing NSIS 3.12.0 with Chocolatey (attempt $($attempt + 1)/$($delays.Count))..."
    & $choco.Source install nsis --version=3.12.0 --yes --no-progress --limit-output | Out-Host
    $candidate = Find-Makensis
    if ($candidate) {
      Write-Host "Verified Chocolatey NSIS $expectedVersion: $candidate"
      Write-Output $candidate
      exit 0
    }

    if ($attempt -lt $delays.Count - 1) {
      Write-Host "Chocolatey did not provide NSIS; retrying after $($delays[$attempt]) seconds."
      Start-Sleep -Seconds $delays[$attempt]
    }
  }
}

Write-Host 'Chocolatey NSIS bootstrap unavailable; using verified official SourceForge archive fallback.'
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$archive = Join-Path $Destination 'nsis-3.12.zip'
$extractRoot = Join-Path $Destination 'extract'
if (Test-Path $extractRoot) {
  Remove-Item $extractRoot -Recurse -Force
}

& curl.exe --fail --silent --show-error --location --retry 5 --retry-all-errors --connect-timeout 20 $archiveUrl --output $archive
if ($LASTEXITCODE -ne 0 -or !(Test-Path $archive -PathType Leaf)) {
  throw 'Unable to download the official NSIS 3.12 fallback archive.'
}

$archiveItem = Get-Item $archive
if ($archiveItem.Length -lt 1MB -or $archiveItem.Length -gt 10MB) {
  throw "Downloaded NSIS archive size is outside the expected range: $($archiveItem.Length) bytes"
}

$actualSha1 = (Get-FileHash $archive -Algorithm SHA1).Hash.ToLowerInvariant()
if (![string]::Equals($actualSha1, $archiveSha1, [StringComparison]::Ordinal)) {
  throw "NSIS fallback archive digest mismatch. Expected $archiveSha1; found $actualSha1"
}

Expand-Archive -Path $archive -DestinationPath $extractRoot -Force
$fallback = Join-Path $extractRoot 'nsis-3.12\bin\makensis.exe'
if (!(Test-Makensis -Path $fallback)) {
  throw 'Verified NSIS archive did not provide the expected makensis v3.12 executable.'
}

Write-Host "Verified official NSIS fallback: $fallback"
Write-Output $fallback
