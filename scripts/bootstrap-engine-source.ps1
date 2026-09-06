param(
  [Parameter(Mandatory = $false)]
  [string]$Destination = 'engine-work',

  [Parameter(Mandatory = $false)]
  [switch]$SkipHooks
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

$destinationPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $Destination))
if (Test-Path $destinationPath) {
  $existingItems = @(Get-ChildItem $destinationPath -Force -ErrorAction SilentlyContinue)
  if ($existingItems.Count -gt 0) {
    throw "Destination must be empty or absent: $destinationPath"
  }
} else {
  New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
}

Push-Location $destinationPath
try {
  Write-Host "Fetching Chromium source for Ghosium into $destinationPath"
  & $fetchCommand.Source --nohooks chromium
  if ($LASTEXITCODE -ne 0) {
    throw "Chromium fetch failed with exit code $LASTEXITCODE"
  }

  $src = Join-Path $destinationPath 'src'
  if (!(Test-Path (Join-Path $src '.git'))) {
    throw 'Chromium fetch did not produce the expected src Git checkout.'
  }

  & git -C $src fetch origin $sourceRevision --no-tags
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to fetch pinned Chromium commit $sourceRevision"
  }
  & git -C $src checkout --detach $sourceRevision
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to detach Chromium checkout at $sourceRevision"
  }

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

  $actualRevision = (& git -C $src rev-parse HEAD).Trim()
  if ($actualRevision -ne $sourceRevision) {
    throw "Checkout drifted from pinned revision. Expected $sourceRevision; found $actualRevision"
  }

  Write-Host "Pinned Chromium source ready at $src"
  Write-Host "Next: $PSScriptRoot/apply-engine-branding.ps1 -SourceRoot '$src'"
} finally {
  Pop-Location
}
