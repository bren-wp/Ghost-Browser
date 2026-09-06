param(
  [Parameter(Mandatory = $true)]
  [string]$SetupPath,

  [Parameter(Mandatory = $true)]
  [string]$Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "Version must be semantic x.y.z; received '$Version'"
}

$setup = (Resolve-Path $SetupPath).Path
$root = Join-Path $env:RUNNER_TEMP 'GhosiumInstallSmoke'
$installedSetup = Join-Path $root 'Installer\Ghosium-Browser-Setup.exe'
$launcher = Join-Path $root 'Ghosium-Browser.exe'
$forbiddenUninstaller = Join-Path $root 'Uninstall.exe'
$uninstallKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GhosiumBrowser'

if (Test-Path $root) {
  Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $uninstallKeyPath) {
  Remove-Item $uninstallKeyPath -Recurse -Force -ErrorAction SilentlyContinue
}

try {
  $install = Start-Process -FilePath $setup -ArgumentList @('/S', "/D=$root") -Wait -PassThru
  if ($install.ExitCode -ne 0) {
    throw "Silent Ghosium installation failed with exit code $($install.ExitCode)"
  }

  foreach ($required in @($installedSetup, $launcher)) {
    if (!(Test-Path $required -PathType Leaf)) {
      throw "Installed Ghosium file is missing: $required"
    }
  }
  if (Test-Path $forbiddenUninstaller -PathType Leaf) {
    throw 'Installation generated a forbidden standalone Uninstall.exe.'
  }
  if (!(Test-Path $uninstallKeyPath)) {
    throw 'Ghosium uninstall registry entry was not created.'
  }

  $reg = Get-ItemProperty $uninstallKeyPath
  if ([string]$reg.DisplayName -ne 'Ghosium Browser') {
    throw "Installed Apps DisplayName mismatch: '$($reg.DisplayName)'"
  }
  if ([string]$reg.DisplayVersion -ne $Version) {
    throw "Installed Apps DisplayVersion mismatch: '$($reg.DisplayVersion)'"
  }
  if ([string]$reg.Publisher -ne 'Brendigo') {
    throw "Installed Apps Publisher mismatch: '$($reg.Publisher)'"
  }
  if ([IO.Path]::GetFullPath([string]$reg.InstallLocation).TrimEnd('\') -ne [IO.Path]::GetFullPath($root).TrimEnd('\')) {
    throw "Installed Apps InstallLocation mismatch: '$($reg.InstallLocation)'"
  }

  $uninstallString = [string]$reg.UninstallString
  $quietUninstallString = [string]$reg.QuietUninstallString
  if (!$uninstallString.Contains('Ghosium-Browser-Setup.exe') -or !$uninstallString.Contains('/UNINSTALL')) {
    throw "UninstallString does not use the same Ghosium Setup executable: '$uninstallString'"
  }
  if ($uninstallString -match '(?i)uninstall\.exe') {
    throw "UninstallString references a standalone uninstaller: '$uninstallString'"
  }
  if (!$quietUninstallString.Contains('Ghosium-Browser-Setup.exe') -or
      !$quietUninstallString.Contains('/UNINSTALL') -or
      !$quietUninstallString.Contains('/S')) {
    throw "QuietUninstallString is invalid: '$quietUninstallString'"
  }

  $remove = Start-Process -FilePath $installedSetup -ArgumentList @('/UNINSTALL', '/S') -Wait -PassThru
  if ($remove.ExitCode -ne 0) {
    throw "Ghosium same-setup uninstall launcher failed with exit code $($remove.ExitCode)"
  }

  $deadline = [DateTime]::UtcNow.AddSeconds(45)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (!(Test-Path $root) -and !(Test-Path $uninstallKeyPath)) {
      break
    }
    Start-Sleep -Milliseconds 500
  }

  if (Test-Path $uninstallKeyPath) {
    throw 'Ghosium uninstall registry entry remains after uninstall.'
  }
  if (Test-Path $root) {
    $remaining = @(Get-ChildItem $root -Force -Recurse -ErrorAction SilentlyContinue)
    throw "Ghosium installation directory remains after uninstall: $root; remaining entries=$($remaining.Count)"
  }

  Write-Host 'Ghosium Setup install -> Installed Apps registration -> same-Setup uninstall smoke test: OK'
}
finally {
  if (Test-Path $uninstallKeyPath) {
    Remove-Item $uninstallKeyPath -Recurse -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path $root) {
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}
