# Ghosium Full-Source Windows Builder

This document describes the machine required to run `.github/workflows/full-source-windows-build.yml` and produce the first verified Ghosium Browser binary compiled from the pinned Chromium source.

The workflow is intentionally manual and self-hosted. A Chromium Windows source checkout and build is too large and long-running to treat as an ordinary PR build.

## Required GitHub Actions labels

Register a Windows x64 self-hosted runner for this repository and ensure it has all four labels:

- `self-hosted`
- `Windows`
- `X64`
- `ghosium-source-builder`

Use GitHub repository **Settings → Actions → Runners → New self-hosted runner** to obtain the current registration command and short-lived registration token. Do not commit runner tokens, credentials, PATs, or service-account secrets to this repository.

Install the runner as a Windows service so the builder remains available for long builds. The service account must have read/write access to the source workspace and enough free disk space.

## Pinned Chromium host requirements

Ghosium pins Chromium source commit `fac978ddceaae0358a2bd69e20a5156ec8dc86ab`. Its Windows build instructions require:

- x86-64 Windows 10 or newer;
- at least 8 GiB RAM; Ghosium recommends 32 GiB or more for reliable full builds;
- NTFS source/build volume;
- at least 100 GiB free disk upstream; Ghosium preflight requires 120 GiB for a fresh checkout and 60 GiB when reusing a checkout;
- Visual Studio 2026, version 18.0 or newer;
- Visual Studio workload **Desktop development with C++**;
- Visual Studio component **ATL/MFC support**;
- Windows 11 SDK `10.0.28000.2270`;
- Windows SDK Debugging Tools `10.0.26100.3323` or newer;
- current Git for Windows;
- Chromium `depot_tools` at the front of `PATH`;
- `DEPOT_TOOLS_WIN_TOOLCHAIN=0`;
- a source workspace path without spaces.

For practical build times, 16 or more logical processors and a fast SSD are recommended. Chromium itself notes that much more RAM and CPU can materially improve build time.

## Install depot_tools

Use a short path without spaces, for example:

```powershell
New-Item -ItemType Directory -Force C:\src | Out-Null
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git C:\src\depot_tools
```

Put `C:\src\depot_tools` at the **front** of the service account's `PATH`. It must resolve before unrelated Python or Git shims.

Set the external toolchain mode for the runner service account:

```powershell
[Environment]::SetEnvironmentVariable('DEPOT_TOOLS_WIN_TOOLCHAIN', '0', 'User')
```

After changing `PATH` or environment variables, restart the GitHub Actions runner service so it inherits the new environment.

Run `gclient` once from `cmd.exe` as the runner service account before the first workflow run. Chromium's upstream instructions specifically warn that the first Windows bootstrap should not be done from Cygwin or another Unix compatibility shell.

## Git configuration

Configure the runner service account:

```powershell
git config --global core.autocrlf false
git config --global core.filemode false
git config --global core.preloadindex true
git config --global core.fscache true
git config --global core.longpaths true
```

The Ghosium builder preflight requires `core.autocrlf=false`, `core.filemode=false`, `core.fscache=true`, and `core.longpaths=true`.

## Source workspace

A persistent checkout avoids downloading the complete Chromium tree for every manual build. A recommended dedicated location is:

```text
C:\src\ghosium-chromium
```

Set the runner service account environment variable:

```powershell
[Environment]::SetEnvironmentVariable('GHOSIUM_SOURCE_WORK', 'C:\src\ghosium-chromium', 'User')
```

Restart the runner service after setting it.

Do not place this workspace on FAT32/exFAT or a path containing spaces. Do not share the same `depot_tools` checkout between native Windows and WSL builds.

## Preflight

From a Ghosium repository checkout on the builder, run:

```powershell
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
.\scripts\verify-source-builder-host.ps1 `
  -WorkRoot 'C:\src\ghosium-chromium' `
  -ReportPath '.\artifacts\full-source\GHOSIUM-BUILDER-READY.json'
```

The script fails closed if required compiler, SDK, filesystem, disk, Git, or `depot_tools` invariants are missing. It does not write secrets to its report.

## Running the full-source build

Once the runner appears **Online** in GitHub with the `ghosium-source-builder` label:

1. Open **Actions**.
2. Select **Ghosium Full-Source Windows Build**.
3. Choose **Run workflow** on `main`.
4. Keep the runner online until the workflow finishes.

A successful workflow must complete these stages:

1. builder preflight;
2. pinned Chromium source bootstrap;
3. Ghosium source branding and verification;
4. deterministic Windows x64 GN configuration;
5. `autoninja -C out/Ghosium chrome mini_installer`;
6. source-built binary verification;
7. SHA-256/provenance generation;
8. upload of the verified `ghosium-full-source-windows-x64` artifact.

The first full-source build is not considered complete merely because the workflow is configured. Completion requires an actual successful Actions run and verified produced artifacts.

## Security notes

- Never put GitHub runner registration tokens, PATs, signing private keys, passwords, or API credentials in repository files.
- Keep the builder dedicated to trusted repository workflows where practical.
- Keep Visual Studio, Windows SDK security fixes, Git, and the runner application patched while preserving the pinned toolchain requirements above.
- Do not disable Chromium sandboxing, certificate validation, process isolation, extension signature verification, or update signature verification to make a build pass.
- `third_party/` source attribution and licenses must remain intact.
