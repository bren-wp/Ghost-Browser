param(
  [Parameter(Mandatory = $false)]
  [string]$Destination = 'engine-work',

  [Parameter(Mandatory = $false)]
  [switch]$SkipHooks,

  [Parameter(Mandatory = $false)]
  [switch]$ReuseExisting
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
if ($sourceRevision -notmatch '^[0-9a-f]{40}$') {
  throw 'ENGINE_SOURCE_REVISION is not a valid pinned Git commit.'
}

$fetchCommand = Get-Command fetch -ErrorAction SilentlyContinue
$gclientCommand = Get-Command gclient -ErrorAction SilentlyContinue
if (!$fetchCommand -or !$gclientCommand) {
  throw 'Chromium depot_tools must be installed and on PATH before bootstrapping the full-source checkout.'
}

if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
  $env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
}

$destinationPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Destination))
$src = Join-Path $destinationPath 'src'
$existingItems = @()
if (Test-Path $destinationPath) {
  $existingItems = @(Get-ChildItem $destinationPath -Force -ErrorAction SilentlyContinue)
}

$reuseCheckout = $existingItems.Count -gt 0
if ($reuseCheckout -and !$ReuseExisting) {
  throw "Destination is not empty. Pass -ReuseExisting only for a controlled Chromium builder checkout: $destinationPath"
}

if ($reuseCheckout) {
  if (!(Test-Path (Join-Path $src '.git')) -or !(Test-Path (Join-Path $destinationPath '.gclient') -PathType Leaf)) {
    throw "Existing destination is not a reusable Chromium depot_tools checkout: $destinationPath"
  }

  Write-Host "Reusing controlled Chromium checkout at $destinationPath"
  & git -C $src reset --hard HEAD
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to reset the reusable Chromium checkout.'
  }
  & git -C $src clean -ffd
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to remove untracked source files from the reusable Chromium checkout.'
  }
} else {
  New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
  Push-Location $destinationPath
  try {
    Write-Host "Fetching Chromium source for Ghosium into $destinationPath"
    & $fetchCommand.Source --nohooks --no-history chromium
    if ($LASTEXITCODE -ne 0) {
      throw "Chromium fetch failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }

  if (!(Test-Path (Join-Path $src '.git'))) {
    throw 'Chromium fetch did not produce the expected src Git checkout.'
  }
}

& git -C $src fetch origin $sourceRevision --no-tags
if ($LASTEXITCODE -ne 0) {
  throw "Unable to fetch pinned Chromium commit $sourceRevision"
}
& git -C $src checkout --detach $sourceRevision
if ($LASTEXITCODE -ne 0) {
  throw "Unable to detach Chromium checkout at $sourceRevision"
}
& git -C $src reset --hard $sourceRevision
if ($LASTEXITCODE -ne 0) {
  throw "Unable to reset Chromium checkout to pinned revision $sourceRevision"
}

Push-Location $destinationPath
try {
  $syncArguments = @('sync', '--with_branch_heads', '--with_tags', '--revision', "src@$sourceRevision")
  if ($SkipHooks) {
    $syncArguments += '--nohooks'
  }
  & $gclientCommand.Source @syncArguments
  if ($LASTEXITCODE -ne 0) {
    throw "gclient sync failed with exit code $LASTEXITCODE"
  }

  if (!$SkipHooks) {
    & $gclientCommand.Source runhooks
    if ($LASTEXITCODE -ne 0) {
      throw "gclient runhooks failed with exit code $LASTEXITCODE"
    }
  }
} finally {
  Pop-Location
}

$actualRevision = (& git -C $src rev-parse HEAD).Trim()
if ($actualRevision -ne $sourceRevision) {
  throw "Checkout drifted from pinned revision. Expected $sourceRevision; found $actualRevision"
}

Write-Host "Pinned Chromium source ready at $src"
Write-Host "Next: $PSScriptRoot/apply-engine-branding.ps1 -SourceRoot '$src'"
