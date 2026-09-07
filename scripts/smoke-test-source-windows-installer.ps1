param(
  [Parameter(Mandatory = $true)]
  [string]$MiniInstallerPath,

  [Parameter(Mandatory = $false)]
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'The Ghosium source-built installer smoke test must run on Windows.'
}

$miniInstaller = (Resolve-Path $MiniInstallerPath).Path
$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
if (!$localAppData) {
  throw 'Unable to resolve LOCALAPPDATA for the source-built installer smoke test.'
}

$productRoot = Join-Path $localAppData 'Brendigo\Ghosium'
$installRoot = Join-Path $productRoot 'Application'
$defaultUserDataRoot = Join-Path $productRoot 'User Data'
$uninstallRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$smokeRoot = Join-Path ([IO.Path]::GetTempPath()) "ghosium-source-installer-smoke-$PID"
$runtimeProfile = Join-Path $smokeRoot 'runtime-profile'
$runtimeStdout = Join-Path $smokeRoot 'runtime.stdout.txt'
$runtimeStderr = Join-Path $smokeRoot 'runtime.stderr.txt'
$installLog = Join-Path $smokeRoot 'install.log'
$uninstallLog = Join-Path $smokeRoot 'uninstall.log'
$pathTrimCharacters = [char[]]@('\', '/')

New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null

function Get-GhosiumUninstallEntries {
  if (!(Test-Path $uninstallRoot)) {
    return @()
  }

  return @(
    Get-ChildItem $uninstallRoot -ErrorAction SilentlyContinue |
      ForEach-Object {
        $property = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($property) {
          $displayNameProperty = $property.PSObject.Properties['DisplayName']
          if ($displayNameProperty -and [string]$displayNameProperty.Value -eq 'Ghosium Browser') {
            [pscustomobject]@{
              KeyPath = $_.PSPath
              KeyName = $_.PSChildName
              Property = $property
            }
          }
        }
      }
  )
}

function Get-LogTail {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (!(Test-Path $Path -PathType Leaf)) {
    return '(installer log was not created)'
  }
  return ((Get-Content $Path -Tail 80 -ErrorAction SilentlyContinue) -join [Environment]::NewLine)
}

function Start-ProcessWithTimeout {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$ArgumentList,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [Parameter(Mandatory = $true)][string]$Description,
    [Parameter(Mandatory = $false)][string]$RedirectStandardOutput,
    [Parameter(Mandatory = $false)][string]$RedirectStandardError
  )

  $startParams = @{
    FilePath = $FilePath
    ArgumentList = $ArgumentList
    PassThru = $true
  }
  if ($RedirectStandardOutput) {
    $startParams.RedirectStandardOutput = $RedirectStandardOutput
  }
  if ($RedirectStandardError) {
    $startParams.RedirectStandardError = $RedirectStandardError
  }

  $process = Start-Process @startParams
  if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
    try {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    } catch {
      Write-Warning "Unable to terminate timed-out process $($process.Id): $($_.Exception.Message)"
    }
    throw "$Description timed out after $TimeoutSeconds seconds."
  }
  return $process
}

function Wait-UntilRemoved {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Condition,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (& $Condition) {
      return
    }
    Start-Sleep -Milliseconds 500
  }
  throw "Timed out waiting for cleanup: $Description"
}

function Find-InstalledSetup {
  if (!(Test-Path $installRoot -PathType Container)) {
    return $null
  }

  $candidates = @(
    Get-ChildItem $installRoot -Recurse -File -Filter 'setup.exe' -ErrorAction SilentlyContinue |
      Where-Object { $_.Directory -and $_.Directory.Name -eq 'Installer' }
  )
  if ($candidates.Count -eq 0) {
    return $null
  }
  return $candidates | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
}

$preexistingEntries = @(Get-GhosiumUninstallEntries)
if (Test-Path $installRoot -PathType Container) {
  throw "Refusing destructive source-installer smoke because a Ghosium installation already exists: $installRoot"
}
if (Test-Path $defaultUserDataRoot -PathType Container) {
  throw "Refusing destructive source-installer smoke because Ghosium user data already exists: $defaultUserDataRoot"
}
if ($preexistingEntries.Count -gt 0) {
  throw "Refusing destructive source-installer smoke because $($preexistingEntries.Count) Ghosium uninstall registration(s) already exist."
}

$installExitCode = $null
$uninstallExitCode = $null
$runtimeExitCode = $null
$runtimeSmokePassed = $false
$installedChromeVersion = $null
$uninstallRegistryKey = $null
$cleanupAttempted = $false
$completed = $false

try {
  # Chromium mini_installer forwards these switches to setup.exe. Keep this a
  # per-user install so the smoke does not require elevation on the dedicated
  # self-hosted builder. Prevent any first-install browser launch.
  $installArguments = @(
    '--verbose-logging',
    '--do-not-launch-chrome',
    '--do-not-register-for-update-launch',
    "--log-file=`"$installLog`""
  )
  $install = Start-ProcessWithTimeout `
    -FilePath $miniInstaller `
    -ArgumentList $installArguments `
    -TimeoutSeconds 180 `
    -Description 'Source-built Ghosium mini_installer'
  $installExitCode = $install.ExitCode
  if ($installExitCode -ne 0) {
    throw "Source-built Ghosium mini_installer failed with exit code $installExitCode.`n$(Get-LogTail -Path $installLog)"
  }

  if (!(Test-Path $installRoot -PathType Container)) {
    throw "Source-built installer did not create the expected Ghosium application directory: $installRoot`n$(Get-LogTail -Path $installLog)"
  }

  $chromeCandidates = @(Get-ChildItem $installRoot -Recurse -File -Filter 'chrome.exe' -ErrorAction SilentlyContinue)
  if ($chromeCandidates.Count -lt 1) {
    throw "Installed source-built Ghosium chrome.exe was not found under $installRoot"
  }
  $installedChrome = $chromeCandidates | Sort-Object FullName | Select-Object -First 1
  $chromeInfo = $installedChrome.VersionInfo
  if ([string]$chromeInfo.ProductName -ne 'Ghosium Browser') {
    throw "Installed chrome.exe ProductName mismatch: '$($chromeInfo.ProductName)'"
  }
  if ([string]$chromeInfo.CompanyName -ne 'Brendigo') {
    throw "Installed chrome.exe CompanyName mismatch: '$($chromeInfo.CompanyName)'"
  }
  if (!$chromeInfo.ProductVersion) {
    throw 'Installed chrome.exe ProductVersion is empty.'
  }
  $installedChromeVersion = [string]$chromeInfo.ProductVersion

  $entries = @(Get-GhosiumUninstallEntries)
  if ($entries.Count -ne 1) {
    throw "Expected exactly one Ghosium Browser uninstall registration after installation; found $($entries.Count)."
  }
  $entry = $entries[0]
  $uninstallRegistryKey = [string]$entry.KeyName
  $reg = $entry.Property
  $uninstallStringProperty = $reg.PSObject.Properties['UninstallString']
  if (!$uninstallStringProperty -or ![string]$uninstallStringProperty.Value) {
    throw 'Installed Ghosium uninstall registration is missing UninstallString.'
  }
  $uninstallString = [string]$uninstallStringProperty.Value
  if ($uninstallString -notmatch '(?i)setup\.exe' -or $uninstallString -notmatch '(?i)--uninstall') {
    throw "Installed Ghosium UninstallString is not setup.exe --uninstall based: '$uninstallString'"
  }

  $installLocationProperty = $reg.PSObject.Properties['InstallLocation']
  if ($installLocationProperty -and [string]$installLocationProperty.Value) {
    $registeredInstall = [IO.Path]::GetFullPath([string]$installLocationProperty.Value).TrimEnd($pathTrimCharacters)
    $expectedInstall = [IO.Path]::GetFullPath($installRoot).TrimEnd($pathTrimCharacters)
    if ($registeredInstall -ne $expectedInstall) {
      throw "Installed Ghosium InstallLocation mismatch: '$($installLocationProperty.Value)'"
    }
  }

  $installedSetup = Find-InstalledSetup
  if (!$installedSetup) {
    throw "Installed source-built setup.exe was not found under $installRoot"
  }
  if ($uninstallString -notlike "*$($installedSetup.Name)*") {
    throw "UninstallString does not reference the installed setup executable: '$uninstallString'"
  }

  # Exercise the installed layout, not the loose build-tree executable. This
  # catches missing DLL/resource/install-layout problems that a pre-install
  # chrome.exe smoke cannot detect.
  $runtimeArguments = @(
    '--headless=new',
    '--disable-gpu',
    '--disable-sync',
    '--no-pings',
    '--no-first-run',
    "--user-data-dir=`"$runtimeProfile`"",
    '--dump-dom',
    'data:text/html,<html><body>ghosium-source-installed-runtime-ok</body></html>'
  )
  $runtime = Start-ProcessWithTimeout `
    -FilePath $installedChrome.FullName `
    -ArgumentList $runtimeArguments `
    -TimeoutSeconds 60 `
    -Description 'Installed source-built Ghosium runtime smoke' `
    -RedirectStandardOutput $runtimeStdout `
    -RedirectStandardError $runtimeStderr
  $runtimeExitCode = $runtime.ExitCode
  $runtimeOutput = if (Test-Path $runtimeStdout -PathType Leaf) { Get-Content $runtimeStdout -Raw } else { '' }
  $runtimeError = if (Test-Path $runtimeStderr -PathType Leaf) { Get-Content $runtimeStderr -Raw } else { '' }
  if ($runtimeExitCode -ne 0 -or !$runtimeOutput.Contains('ghosium-source-installed-runtime-ok')) {
    Write-Host $runtimeOutput
    Write-Host $runtimeError
    throw "Installed source-built Ghosium runtime smoke failed with exit code $runtimeExitCode."
  }
  $runtimeSmokePassed = $true

  $uninstallArguments = @(
    '--uninstall',
    '--force-uninstall',
    '--delete-profile',
    '--verbose-logging',
    "--log-file=`"$uninstallLog`""
  )
  $remove = Start-ProcessWithTimeout `
    -FilePath $installedSetup.FullName `
    -ArgumentList $uninstallArguments `
    -TimeoutSeconds 120 `
    -Description 'Installed Ghosium setup.exe uninstall'
  $uninstallExitCode = $remove.ExitCode
  if ($uninstallExitCode -ne 0) {
    throw "Installed Ghosium setup.exe uninstall failed with exit code $uninstallExitCode.`n$(Get-LogTail -Path $uninstallLog)"
  }

  Wait-UntilRemoved `
    -Condition { !(Test-Path $installRoot) -and @(Get-GhosiumUninstallEntries).Count -eq 0 } `
    -TimeoutSeconds 60 `
    -Description 'Ghosium application directory and uninstall registration'

  if (Test-Path $defaultUserDataRoot) {
    throw "Default Ghosium user-data directory remains after --delete-profile uninstall: $defaultUserDataRoot"
  }

  if (!$ReportPath) {
    $ReportPath = Join-Path (Get-Location).Path 'GHOSIUM-SOURCE-INSTALLER-SMOKE.json'
  } elseif (![IO.Path]::IsPathRooted($ReportPath)) {
    $ReportPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $ReportPath))
  }
  $reportDirectory = Split-Path -Parent $ReportPath
  if ($reportDirectory) {
    New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  }

  [ordered]@{
    schemaVersion = 1
    product = 'Ghosium Browser'
    architecture = 'windows-x64'
    installMode = 'per-user'
    miniInstallerSha256 = (Get-FileHash $miniInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
    installedChromeProductVersion = $installedChromeVersion
    installedChromeProductName = 'Ghosium Browser'
    publisher = 'Brendigo'
    uninstallRegistryKey = $uninstallRegistryKey
    installExitCode = $installExitCode
    installedRuntimeSmoke = [ordered]@{
      passed = $runtimeSmokePassed
      exitCode = $runtimeExitCode
      timeoutSeconds = 60
      sandboxDisabled = $false
      isolatedProfile = $true
    }
    uninstall = [ordered]@{
      setupBased = $true
      forceUninstall = $true
      deleteProfile = $true
      exitCode = $uninstallExitCode
      timeoutSeconds = 120
      applicationDirectoryRemoved = !(Test-Path $installRoot)
      registrationRemoved = @(Get-GhosiumUninstallEntries).Count -eq 0
      defaultUserDataRemoved = !(Test-Path $defaultUserDataRoot)
    }
    repositoryCommit = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { $null }
    verifiedUtc = [DateTime]::UtcNow.ToString('o')
  } | ConvertTo-Json -Depth 5 | Set-Content $ReportPath -Encoding utf8

  $completed = $true
  Write-Host 'Source-built Ghosium mini_installer -> installed runtime -> registered setup.exe uninstall smoke test: OK'
  Write-Host "Installed engine version: $installedChromeVersion"
  Write-Host "Installer smoke provenance: $ReportPath"
}
finally {
  if (!$completed -and (Test-Path $installRoot -PathType Container)) {
    $cleanupSetup = Find-InstalledSetup
    if ($cleanupSetup) {
      $cleanupAttempted = $true
      try {
        [void](Start-ProcessWithTimeout `
          -FilePath $cleanupSetup.FullName `
          -ArgumentList @('--uninstall', '--force-uninstall', '--delete-profile') `
          -TimeoutSeconds 120 `
          -Description 'Best-effort Ghosium cleanup uninstall')
      } catch {
        Write-Warning "Best-effort Ghosium cleanup failed after installer smoke error: $($_.Exception.Message)"
      }
    }
  }

  if (!$completed -and $cleanupAttempted) {
    Write-Host 'Best-effort source-installer cleanup was attempted after smoke-test failure.'
  }
  Remove-Item $runtimeProfile -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $smokeRoot -Recurse -Force -ErrorAction SilentlyContinue
}
