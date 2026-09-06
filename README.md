# Ghosium Browser

```powershell
npm install
npm run audit
npm run build
cargo check --manifest-path src-tauri/Cargo.toml --target x86_64-pc-windows-msvc
npm run tauri build -- --target x86_64-pc-windows-msvc --bundles ns

## Privacy boundary
