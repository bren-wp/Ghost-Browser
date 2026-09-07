param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$OutDir = 'out/Ghosium',

  [Parameter(Mandatory = $false)]
  [string]$ProvenancePath,

  [Parameter(Mandatory = $false)]
  [switch]$RunRuntimeSmoke
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

# Uninstall is deliberately implemented by the installed setup.exe invoked with
# Chromium's normal --uninstall flow and registered Windows uninstall command.
# Ghosium must not ship a second standalone uninstall executable.
foreach ($forbiddenUninstaller in @(
  'uninstall.exe',
  'Ghosium-Uninstall.exe',
  'Ghosium-Browser-Uninstall.exe'
)) {
  if (Test-Path (Join-Path $outPath $forbiddenUninstaller) -PathType Leaf) {
    throw "Standalone uninstaller is forbidden; use setup.exe --uninstall instead: $forbiddenUninstaller"
  }
}

$uninstallSourceFiles = [ordered]@{
  setupMain = Join-Path $sourceRootResolved 'chrome/installer/setup/setup_main.cc'
  uninstall = Join-Path $sourceRootResolved 'chrome/installer/setup/uninstall.cc'
  installWorker = Join-Path $sourceRootResolved 'chrome/installer/setup/install_worker.cc'
  utilConstants = Join-Path $sourceRootResolved 'chrome/installer/util/util_constants.h'
}
foreach ($entry in $uninstallSourceFiles.GetEnumerator()) {
  if (!(Test-Path $entry.Value -PathType Leaf)) {
    throw "Pinned source is missing required Windows uninstall support: $($entry.Value)"
  }
}

$setupMainText = [IO.File]::ReadAllText($uninstallSourceFiles.setupMain)
$uninstallText = [IO.File]::ReadAllText($uninstallSourceFiles.uninstall)
$installWorkerText = [IO.File]::ReadAllText($uninstallSourceFiles.installWorker)
$utilConstantsText = [IO.File]::ReadAllText($uninstallSourceFiles.utilConstants)

if (!$setupMainText.Contains('HasSwitch(installer::switches::kUninstall)') -or
    !$setupMainText.Contains('UninstallProduct(')) {
  throw 'setup.exe no longer exposes Chromium-compatible --uninstall handling.'
}
if (!$uninstallText.Contains('InstallStatus UninstallProduct(')) {
  throw 'Pinned source no longer contains the browser uninstall implementation.'
}
if (!$utilConstantsText.Contains('kSetupExe[] = L"setup.exe"') -or
    !$utilConstantsText.Contains('kUninstallStringField[] = L"UninstallString"') -or
    !$utilConstantsText.Contains('kUninstallArgumentsField[] = L"UninstallArguments"')) {
  throw 'Windows uninstall registry/setup constants changed unexpectedly.'
}
if (!$installWorkerText.Contains('installer::kUninstallStringField') -or
    !$installWorkerText.Contains('installer::kUninstallArgumentsField')) {
  throw 'Installer no longer registers the setup-based uninstall command.'
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

$setup = Get-Item (Join-Path $outPath 'setup.exe')
$setupInfo = $setup.VersionInfo
$installer = Get-Item (Join-Path $outPath 'mini_installer.exe')
$installerInfo = $installer.VersionInfo
foreach ($binaryInfo in @(
  [pscustomobject]@{ Name = 'setup.exe'; Info = $setupInfo },
  [pscustomobject]@{ Name = 'mini_installer.exe'; Info = $installerInfo }
)) {
  if ($binaryInfo.Info.ProductName -and [string]$binaryInfo.Info.ProductName -match '(?i)\bChromium\b|Google Chrome') {
    throw "$($binaryInfo.Name) exposes legacy product branding in ProductName: '$($binaryInfo.Info.ProductName)'"
  }
  if ($binaryInfo.Info.CompanyName -and [string]$binaryInfo.Info.CompanyName -match '(?i)Google LLC') {
    throw "$($binaryInfo.Name) exposes legacy publisher metadata: '$($binaryInfo.Info.CompanyName)'"
  }
}
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

$runtimeSmokePassed = $false
$runtimeSmokeTimeoutSeconds = 60
if ($RunRuntimeSmoke) {
  $smokeRoot = Join-Path ([IO.Path]::GetTempPath()) "ghosium-source-smoke-$PID"
  $profile = Join-Path $smokeRoot 'profile'
  $stdout = Join-Path $smokeRoot 'stdout.txt'
  $stderr = Join-Path $smokeRoot 'stderr.txt'
  New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null
  $process = $null
  try {
    $runtimeArgs = @(
      '--headless=new',
      '--disable-gpu',
      '--disable-sync',
      '--no-pings',
      '--no-first-run',
      "--user-data-dir=$profile",
      '--dump-dom',
      'data:text/html,<html><body>ghosium-source-runtime-ok</body></html>'
    )
    $process = Start-Process `
      -FilePath $chrome.FullName `
      -ArgumentList $runtimeArgs `
      -PassThru `
      -RedirectStandardOutput $stdout `
      -RedirectStandardError $stderr

    if (!$process.WaitForExit($runtimeSmokeTimeoutSeconds * 1000)) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      throw "Source-built Ghosium runtime smoke exceeded ${runtimeSmokeTimeoutSeconds}s and was terminated."
    }
    $process.Refresh()

    $smokeOutput = if (Test-Path $stdout -PathType Leaf) { Get-Content $stdout -Raw } else { '' }
    $smokeError = if (Test-Path $stderr -PathType Leaf) { Get-Content $stderr -Raw } else { '' }
    if ($process.ExitCode -ne 0 -or !$smokeOutput.Contains('ghosium-source-runtime-ok')) {
      Write-Host $smokeOutput
      Write-Host $smokeError
      throw "Source-built Ghosium runtime smoke failed with exit code $($process.ExitCode)."
    }
    $runtimeSmokePassed = $true
  } finally {
    if ($process -and !$process.HasExited) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $smokeRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
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
  schemaVersion = 2
  product = 'Ghosium Browser'
  ghosiumVersion = $ghosiumVersion
  architecture = 'windows-x64'
  engineSourceRevision = $expectedRevision
  engineProductVersion = [string]$chromeInfo.ProductVersion
  publisher = [string]$chromeInfo.CompanyName
  chromeProductName = [string]$chromeInfo.ProductName
  setupProductName = [string]$setupInfo.ProductName
  installerProductName = [string]$installerInfo.ProductName
  runtimeSmoke = [ordered]@{
    requested = [bool]$RunRuntimeSmoke
    passed = $runtimeSmokePassed
    timeoutSeconds = $runtimeSmokeTimeoutSeconds
    sandboxDisabled = $false
  }
  uninstall = [ordered]@{
    supported = $true
    mechanism = 'setup.exe --uninstall via Windows registered uninstall command'
    standaloneExecutable = $false
  }
  repositoryCommit = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { $null }
  verifiedUtc = [DateTime]::UtcNow.ToString('o')
  sha256 = $hashes
}
$provenance | ConvertTo-Json -Depth 5 | Set-Content $ProvenancePath -Encoding utf8

Write-Host 'Ghosium full-source Windows binary verification: OK'
Write-Host "Engine version: $($chromeInfo.ProductVersion)"
if ($RunRuntimeSmoke) {
  Write-Host "Runtime smoke: passed within ${runtimeSmokeTimeoutSeconds}s without disabling the browser sandbox."
}
Write-Host 'Uninstall: supported through registered setup.exe --uninstall flow; no standalone uninstall.exe'
Write-Host "Provenance: $ProvenancePath"
