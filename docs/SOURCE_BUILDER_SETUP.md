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
- a 64-bit runner process on an actual x64 host, not Windows on ARM;
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
- `DEPOT_TOOLS_UPDATE=0` during the reproducible workflow so `gclient` cannot change the toolchain mid-build;
- `GIT_TERMINAL_PROMPT=0` for unattended operation;
- a source workspace path without spaces.

For practical build times, 16 or more logical processors and a fast SSD are recommended. Chromium itself notes that much more RAM and CPU can materially improve build time.

## Install depot_tools

Use a short path without spaces, for example:

```powershell
New-Item -ItemType Directory -Force C:\src | Out-Null
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git C:\src\depot_tools
```

The Ghosium preflight requires the `depot_tools` checkout to use the official Chromium HTTPS origin and rejects modified tracked files. Its exact Git commit is written to `GHOSIUM-BUILDER-READY.json` so each produced build can be audited later.

Put `C:\src\depot_tools` at the **front** of the service account's `PATH`. It must resolve before unrelated Python or Git shims.

Set the runner service account environment variables:

```powershell
[Environment]::SetEnvironmentVariable('DEPOT_TOOLS_WIN_TOOLCHAIN', '0', 'User')
[Environment]::SetEnvironmentVariable('DEPOT_TOOLS_UPDATE', '0', 'User')
[Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', '0', 'User')
```

The GitHub workflow also sets these values at job scope. Setting them for the service account keeps manual preflight behavior aligned with CI.

After changing `PATH` or environment variables, restart the GitHub Actions runner service so it inherits the new environment.

Before freezing `DEPOT_TOOLS_UPDATE=0`, initialize a clean official depot_tools checkout once as the runner service account. Chromium's upstream instructions recommend performing the first Windows `gclient` bootstrap from `cmd.exe`, not from Cygwin or another Unix compatibility shell. After bootstrap, return the checkout to a clean tracked-file state before running Ghosium preflight.

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

A persistent checkout avoids downloading the complete Chromium tree for every manual build. The default location is deliberately a short persistent path rather than `RUNNER_TEMP`:

```text
C:\src\ghosium-chromium
```

To use another local NTFS drive, set the runner service account environment variable, for example:

```powershell
[Environment]::SetEnvironmentVariable('GHOSIUM_SOURCE_WORK', 'D:\src\ghosium-chromium', 'User')
```

Restart the runner service after setting it.

Do not place this workspace on FAT32/exFAT, a network share, a path containing spaces, or a temporary GitHub runner directory. Do not share the same `depot_tools` checkout between native Windows and WSL builds.

## Preflight

From a Ghosium repository checkout on the builder, run:

```powershell
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
$env:DEPOT_TOOLS_UPDATE = '0'
$env:GIT_TERMINAL_PROMPT = '0'
.\scripts\verify-source-builder-host.ps1 `
  -WorkRoot 'C:\src\ghosium-chromium' `
  -ReportPath '.\artifacts\full-source\GHOSIUM-BUILDER-READY.json'
```

The script fails closed if required architecture, compiler, SDK, filesystem, disk, Git, depot_tools provenance, or unattended-build invariants are missing. It does not write credentials or product API secrets to its report.

The report includes the exact depot_tools Git revision, official origin URL, Windows/Visual Studio/SDK versions, architecture, RAM, CPU count, filesystem, free disk and chosen source workspace.

## Running the full-source build

Once the runner appears **Online** in GitHub with the `ghosium-source-builder` label:

1. Open **Actions**.
2. Select **Ghosium Full-Source Windows Build**.
3. Choose **Run workflow** on `main`.
4. Keep the runner online until the workflow finishes.

A successful workflow must complete these stages:

1. builder preflight and toolchain provenance capture;
2. pinned Chromium source bootstrap;
3. Ghosium source branding and verification;
4. deterministic Windows x64 GN configuration;
5. `autoninja -C out/Ghosium chrome mini_installer`;
6. source-built binary metadata verification;
7. real headless runtime smoke using the newly compiled `chrome.exe`, without `--no-sandbox`;
8. SHA-256/provenance generation;
9. upload of the verified `ghosium-full-source-windows-x64` artifact.

The runtime smoke launches the source-built browser with an isolated temporary profile, loads a local `data:` document, checks a deterministic DOM marker, and fails the build if the executable crashes, exits non-zero, or does not return the expected result. The smoke test does not disable the browser sandbox.

The first full-source build is not considered complete merely because the workflow is configured. Completion requires an actual successful Actions run and verified produced artifacts.

## Security and reproducibility notes

- Never put GitHub runner registration tokens, PATs, signing private keys, passwords, or API credentials in repository files.
- The full-source workflow checks out Ghosium with `persist-credentials: false` so the repository token is not retained in Git configuration on the persistent builder.
- `DEPOT_TOOLS_UPDATE=0` prevents a `gclient` invocation from silently changing depot_tools during a build; update depot_tools deliberately between verified builds, then record the new revision through preflight.
- `GIT_TERMINAL_PROMPT=0` prevents unattended jobs from hanging on interactive authentication prompts.
- Keep the builder dedicated to trusted repository workflows where practical.
- Keep Visual Studio, Windows SDK security fixes, Git, depot_tools and the runner application patched while preserving the pinned build requirements.
- Do not disable Chromium sandboxing, certificate validation, process isolation, extension signature verification, or update signature verification to make a build pass.
- `third_party/` source attribution and licenses must remain intact.
