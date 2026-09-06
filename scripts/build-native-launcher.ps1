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
  'ghosium.ico'
)
foreach ($path in $required) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required native launcher input is missing: $path"
  }
}

$iconBytes = [IO.File]::ReadAllBytes((Resolve-Path 'ghosium.ico'))
if ($iconBytes.Length -lt 4 -or
    $iconBytes[0] -ne 0 -or
    $iconBytes[1] -ne 0 -or
    $iconBytes[2] -ne 1 -or
    $iconBytes[3] -ne 0) {
  throw 'ghosium.ico is not a valid Windows ICO resource.'
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
Write-Host "Ghosium C++20 launcher build and Windows metadata verification: OK"
