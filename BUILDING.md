# Building Ghosium Browser

## Standard Windows release build

The standard CI path builds the Ghosium distribution without compiling the entire upstream engine source tree on a hosted runner.

1. Read `VERSION` and pinned `ENGINE_REVISION`.
2. Validate Ghosium manifests, product links, PHP/JSON web sources and C++-only desktop code.
3. Download the pinned official Windows engine snapshot from its upstream source.
4. Verify archive/source metadata and obtain the corresponding upstream license.
5. Assemble the Ghosium runtime and rename the upstream entry executable to `Ghosium-Engine.exe`.
6. Compile `launcher/main.cpp` using Microsoft C++20 with Windows exploit mitigations.
7. Run launcher and headless engine smoke tests.
8. Build `Ghosium-Browser-Setup.exe` and `Ghosium-Browser-Portable.exe` using NSIS.
9. Publish only those two EXE files as explicit GitHub Release assets. GitHub supplies source-code archives for the tag automatically.

## Desktop source language

Ghosium-owned desktop executable source is C++20 only. HTML, CSS and JSON are presentation/configuration assets. PHP is used only by the separate shared-hosting Search/Store services.

## Local Windows build

Requirements:

- Windows 10/11 x64
- Visual Studio C++ toolchain
- NSIS
- PowerShell
- enough disk space for the pinned engine archive and staging directory

Use the workflow as the canonical reference for compiler/linker flags and packaging definitions.

## Full-source engine build

Deeper product rebranding, internal engine string replacement and first-party extension-store installation require a full upstream source checkout and source patching. That path is intentionally separate from the lightweight release build because the full engine toolchain requires substantially more disk/RAM than a normal hosted runner.

Required upstream notices/licenses must remain intact regardless of branding level.
