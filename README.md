# Ghost Browser

Requirements:

- Windows 10/11 x64
- Node.js 22+
- stable Rust toolchain with `x86_64-pc-windows-msvc`
- Visual Studio C++ Build Tools / Windows SDK

```powershell
npm install
npm run audit
npm run build
cargo check --manifest-path src-tauri/Cargo.toml --target x86_64-pc-windows-msvc
npm run tauri build -- --target x86_64-pc-windows-msvc --bundles ns

## Privacy boundary


## Rendering-engine direction


