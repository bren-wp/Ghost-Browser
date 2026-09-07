param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $false)]
  [string]$OutputPath = 'staging/Ghosium-Browser.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
  throw "Version must be semantic x.y.z; received '$Version'"
}

$major = $Matches[1]
$minor = $Matches[2]
$patch = $Matches[3]

$required = @(
  'launcher/main.cpp',
  'launcher/ghosium.rc',
  'scripts/generate-engine-brand-assets.py'
)
foreach ($path in $required) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required native launcher input is missing: $path"
  }
}

# Generate the canonical Windows icon on every build rather than trusting a
# checked-in binary copy. This ensures Setup, Portable and the launcher all use
# the same deterministic Ghosium mark and the current RC-compatible ICO format.
$python = Get-Command python -ErrorAction SilentlyContinue
if (!$python) {
  $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (!$python) {
  throw 'Python 3 is required to generate the Ghosium Windows icon.'
}

$iconPath = [IO.Path]::GetFullPath('ghosium.ico')
& $python.Source 'scripts/generate-engine-brand-assets.py' --icon-output $iconPath --icon-only
if ($LASTEXITCODE -ne 0 -or !(Test-Path $iconPath -PathType Leaf)) {
  throw 'Deterministic Ghosium Windows icon generation failed.'
}

$iconBytes = [IO.File]::ReadAllBytes($iconPath)
if ($iconBytes.Length -lt 22 -or
    $iconBytes[0] -ne 0 -or
    $iconBytes[1] -ne 0 -or
    $iconBytes[2] -ne 1 -or
    $iconBytes[3] -ne 0) {
  throw 'Generated ghosium.ico has an invalid ICO header.'
}
$iconCount = [BitConverter]::ToUInt16($iconBytes, 4)
if ($iconCount -lt 4) {
  throw "Generated ghosium.ico has too few image frames: $iconCount"
}
$firstImageOffset = [BitConverter]::ToUInt32($iconBytes, 18)
if ($firstImageOffset + 4 -gt $iconBytes.Length) {
  throw 'Generated ghosium.ico contains an invalid first-frame offset.'
}
$dibHeaderSize = [BitConverter]::ToUInt32($iconBytes, [int]$firstImageOffset)
if ($dibHeaderSize -ne 40) {
  throw "Generated ghosium.ico is not an RC-compatible BITMAPINFOHEADER icon: header=$dibHeaderSize"
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Test-Path $vswhere -PathType Leaf)) {
  throw 'vswhere.exe was not found.'
}

$vsPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if (!$vsPath) {
  throw 'Visual Studio C++ toolchain was not found.'
}

$devCmd = Join-Path $vsPath 'Common7\Tools\VsDevCmd.bat'
if (!(Test-Path $devCmd -PathType Leaf)) {
  throw "Visual Studio developer environment script was not found: $devCmd"
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$outputDir = Split-Path -Parent $outputFullPath
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$resPath = Join-Path $outputDir 'ghosium-launcher.res'

$commands = @(
  "call `"$devCmd`" -arch=x64 -host_arch=x64",
  "rc.exe /nologo /dGHOSIUM_VERSION_MAJOR=$major /dGHOSIUM_VERSION_MINOR=$minor /dGHOSIUM_VERSION_PATCH=$patch /fo `"$resPath`" launcher\ghosium.rc",
  "cl.exe /nologo /std:c++20 /O2 /W4 /EHsc /DUNICODE /D_UNICODE /GS /sdl /guard:cf /MT launcher\main.cpp `"$resPath`" /Fe:`"$outputFullPath`" /link /SUBSYSTEM:WINDOWS /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA /GUARD:CF /CETCOMPAT user32.lib shell32.lib"
)

& cmd.exe /d /s /c ($commands -join ' && ')
if ($LASTEXITCODE -ne 0) {
  throw "Ghosium C++20 launcher/resource build failed with exit code $LASTEXITCODE"
}
if (!(Test-Path $outputFullPath -PathType Leaf)) {
  throw "Ghosium launcher was not produced: $outputFullPath"
}

$info = (Get-Item $outputFullPath).VersionInfo
$expectedProductVersion = "$Version.0"
$metadata = [ordered]@{
  ProductName = [string]$info.ProductName
  CompanyName = [string]$info.CompanyName
  FileDescription = [string]$info.FileDescription
  OriginalFilename = [string]$info.OriginalFilename
  ProductVersion = [string]$info.ProductVersion
}

if ($metadata.ProductName -ne 'Ghosium Browser') {
  throw "Launcher ProductName mismatch: '$($metadata.ProductName)'"
}
if ($metadata.CompanyName -ne 'Brendigo') {
  throw "Launcher CompanyName mismatch: '$($metadata.CompanyName)'"
}
if ($metadata.FileDescription -ne 'Ghosium Browser') {
  throw "Launcher FileDescription mismatch: '$($metadata.FileDescription)'"
}
if ($metadata.OriginalFilename -ne 'Ghosium-Browser.exe') {
  throw "Launcher OriginalFilename mismatch: '$($metadata.OriginalFilename)'"
}
if ($metadata.ProductVersion -ne $expectedProductVersion) {
  throw "Launcher ProductVersion mismatch: '$($metadata.ProductVersion)' expected '$expectedProductVersion'"
}

Remove-Item $resPath -Force -ErrorAction SilentlyContinue
Write-Host "Ghosium C++20 launcher build, icon and Windows metadata verification: OK"
