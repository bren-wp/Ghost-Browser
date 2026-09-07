param(
  [Parameter(Mandatory = $false)]
  [string]$WorkRoot,

  [Parameter(Mandatory = $false)]
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$requiredVisualStudioMajor = 18
$requiredWindowsSdk = '10.0.28000.2270'
$minimumDebuggerVersion = [version]'10.0.26100.3323'
$minimumRamGiB = 8
$recommendedRamGiB = 32
$recommendedLogicalProcessors = 16
$minimumFreshFreeGiB = 120
$minimumReuseFreeGiB = 60

function Require-Command {
  param([Parameter(Mandatory = $true)][string]$Name)

  $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
  if (!$command) {
    throw "Required Chromium build command is missing from PATH: $Name"
  }
  return $command
}

function Get-NumericFileVersion {
  param([Parameter(Mandatory = $true)][string]$Path)

  $versionText = [string](Get-Item $Path).VersionInfo.FileVersion
  $match = [regex]::Match($versionText, '\d+\.\d+\.\d+\.\d+')
  if (!$match.Success) {
    throw "Unable to determine numeric file version for $Path; value='$versionText'"
  }
  return [version]$match.Value
}

function Require-GitConfig {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Expected
  )

  $value = (& git config --global --get $Name 2>$null | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$value)) {
    throw "Required global Git setting is missing: $Name=$Expected"
  }
  if (![string]::Equals(([string]$value).Trim(), $Expected, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Global Git setting $Name must be '$Expected'; found '$value'"
  }
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'Ghosium full-source builds require a Windows host.'
}
if (![Environment]::Is64BitOperatingSystem) {
  throw 'Ghosium full-source builds require 64-bit Windows.'
}

$git = Require-Command -Name 'git'
$fetch = Require-Command -Name 'fetch'
$gclient = Require-Command -Name 'gclient'
$gn = Require-Command -Name 'gn'
$autoninja = Require-Command -Name 'autoninja'
$python3 = Require-Command -Name 'python3'

$depotToolsRoot = [IO.Path]::GetFullPath((Split-Path -Parent $fetch.Source)).TrimEnd('\')
foreach ($tool in @($gclient, $gn, $autoninja, $python3)) {
  $toolPath = [IO.Path]::GetFullPath($tool.Source)
  if (!$toolPath.StartsWith($depotToolsRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Chromium build tool '$($tool.Name)' must resolve from depot_tools before other toolchains. Found: $toolPath; depot_tools: $depotToolsRoot"
  }
}

if ($env:DEPOT_TOOLS_WIN_TOOLCHAIN -ne '0') {
  throw "DEPOT_TOOLS_WIN_TOOLCHAIN must be set to 0 for the external Windows source builder; found '$($env:DEPOT_TOOLS_WIN_TOOLCHAIN)'"
}

Require-GitConfig -Name 'core.autocrlf' -Expected 'false'
Require-GitConfig -Name 'core.filemode' -Expected 'false'
Require-GitConfig -Name 'core.fscache' -Expected 'true'
Require-GitConfig -Name 'core.longpaths' -Expected 'true'

if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  if (![string]::IsNullOrWhiteSpace($env:GHOSIUM_SOURCE_WORK)) {
    $WorkRoot = $env:GHOSIUM_SOURCE_WORK
  } elseif (![string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    $WorkRoot = Join-Path $env:RUNNER_TEMP 'ghosium-chromium'
  } else {
    $WorkRoot = 'C:\src\ghosium-chromium'
  }
}

$resolvedWorkRoot = [IO.Path]::GetFullPath($WorkRoot)
if ($resolvedWorkRoot -match '\s') {
  throw "Chromium source workspace path must not contain spaces: $resolvedWorkRoot"
}
if ($resolvedWorkRoot -notmatch '^[A-Za-z]:\\') {
  throw "Chromium source workspace must use a local Windows drive: $resolvedWorkRoot"
}
New-Item -ItemType Directory -Force -Path $resolvedWorkRoot | Out-Null

$driveLetter = $resolvedWorkRoot.Substring(0, 1)
$volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
if (![string]::Equals([string]$volume.FileSystem, 'NTFS', [StringComparison]::OrdinalIgnoreCase)) {
  throw "Chromium source workspace must be on NTFS. Drive ${driveLetter}: uses '$($volume.FileSystem)'."
}

$drive = Get-PSDrive -Name $driveLetter -ErrorAction Stop
$reuse = Test-Path (Join-Path $resolvedWorkRoot 'src\.git')
$requiredFreeGiB = if ($reuse) { $minimumReuseFreeGiB } else { $minimumFreshFreeGiB }
$freeGiB = [math]::Floor($drive.Free / 1GB)
if ($freeGiB -lt $requiredFreeGiB) {
  throw "Insufficient free disk for Chromium source build. Required at least ${requiredFreeGiB} GiB; found ${freeGiB} GiB on $($drive.Root)"
}

$computerSystem = Get-CimInstance Win32_ComputerSystem
$ramGiB = [math]::Floor([double]$computerSystem.TotalPhysicalMemory / 1GB)
$logicalProcessors = [int]$computerSystem.NumberOfLogicalProcessors
if ($ramGiB -lt $minimumRamGiB) {
  throw "Chromium requires at least ${minimumRamGiB} GiB RAM; found ${ramGiB} GiB."
}
if ($ramGiB -lt $recommendedRamGiB) {
  Write-Warning "Builder has ${ramGiB} GiB RAM. Ghosium recommends at least ${recommendedRamGiB} GiB for reliable full builds."
}
if ($logicalProcessors -lt $recommendedLogicalProcessors) {
  Write-Warning "Builder has $logicalProcessors logical processors. At least $recommendedLogicalProcessors is recommended for practical full-build times."
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Test-Path $vswhere -PathType Leaf)) {
  throw 'Visual Studio Installer vswhere.exe was not found.'
}
$vsPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Component.VC.ATLMFC -property installationPath | Select-Object -First 1)
$vsVersion = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Component.VC.ATLMFC -property installationVersion | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace([string]$vsPath) -or [string]::IsNullOrWhiteSpace([string]$vsVersion)) {
  throw 'Visual Studio with Desktop development with C++ and ATL/MFC support was not found.'
}
$vsMajor = [int](([string]$vsVersion).Split('.')[0])
if ($vsMajor -lt $requiredVisualStudioMajor) {
  throw "Pinned Chromium requires Visual Studio 2026 (18.x or newer); found $vsVersion"
}

$windowsKitsRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' -Name KitsRoot10 -ErrorAction Stop).KitsRoot10
$sdkInclude = Join-Path $windowsKitsRoot "Include\$requiredWindowsSdk\um\Windows.h"
$sdkLibrary = Join-Path $windowsKitsRoot "Lib\$requiredWindowsSdk\um\x64\Kernel32.Lib"
if (!(Test-Path $sdkInclude -PathType Leaf) -or !(Test-Path $sdkLibrary -PathType Leaf)) {
  throw "Required Windows 11 SDK $requiredWindowsSdk is not installed completely under $windowsKitsRoot"
}

$debugger = Join-Path $windowsKitsRoot 'Debuggers\x64\cdb.exe'
if (!(Test-Path $debugger -PathType Leaf)) {
  throw 'Windows SDK Debugging Tools for x64 are required but cdb.exe was not found.'
}
$debuggerVersion = Get-NumericFileVersion -Path $debugger
if ($debuggerVersion -lt $minimumDebuggerVersion) {
  throw "Windows SDK Debugging Tools must be $minimumDebuggerVersion or newer; found $debuggerVersion"
}

$gitVersion = (& $git.Source --version | Select-Object -First 1).Trim()
$os = Get-CimInstance Win32_OperatingSystem
$report = [ordered]@{
  schemaVersion = 1
  status = 'ready'
  architecture = 'windows-x64'
  osCaption = [string]$os.Caption
  osVersion = [string]$os.Version
  ramGiB = $ramGiB
  logicalProcessors = $logicalProcessors
  workRoot = $resolvedWorkRoot
  reusableCheckout = [bool]$reuse
  fileSystem = [string]$volume.FileSystem
  freeDiskGiB = $freeGiB
  requiredFreeDiskGiB = $requiredFreeGiB
  depotToolsRoot = $depotToolsRoot
  gitVersion = $gitVersion
  visualStudioVersion = [string]$vsVersion
  windowsSdkVersion = $requiredWindowsSdk
  debuggingToolsVersion = $debuggerVersion.ToString()
  depotToolsWinToolchain = [string]$env:DEPOT_TOOLS_WIN_TOOLCHAIN
}

if (![string]::IsNullOrWhiteSpace($ReportPath)) {
  $reportFullPath = [IO.Path]::GetFullPath($ReportPath)
  $reportDirectory = Split-Path -Parent $reportFullPath
  if ($reportDirectory) {
    New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  }
  $report | ConvertTo-Json -Depth 4 | Set-Content $reportFullPath -Encoding utf8
  Write-Host "Builder readiness report: $reportFullPath"
}

if (![string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
  "work_root=$resolvedWorkRoot" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
  "reuse=$($reuse.ToString().ToLowerInvariant())" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

Write-Host 'Ghosium full-source Windows builder preflight: OK'
Write-Host "Workspace: $resolvedWorkRoot"
Write-Host "Reusable checkout: $reuse"
Write-Host "NTFS free disk: ${freeGiB} GiB"
Write-Host "RAM: ${ramGiB} GiB; logical processors: $logicalProcessors"
Write-Host "Visual Studio: $vsVersion"
Write-Host "Windows SDK: $requiredWindowsSdk; Debugging Tools: $debuggerVersion"
Write-Host "depot_tools: $depotToolsRoot"
