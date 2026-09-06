use crate::profile::{ProfileStore, VaultEntry, normalize_origin};
use tauri::{AppHandle, Manager, State};
use uuid::Uuid;

const MAX_SECRET_BYTES: usize = 2_048;
const VAULT_PREFIX: &str = "GhosiumBrowser/Vault/";
const MAIL_PREFIX: &str = "GhosiumBrowser/Mail/";

#[cfg(windows)]
fn to_wide(value: &str) -> Vec<u16> {
    value.encode_utf16().chain(std::iter::once(0)).collect()
}

#[cfg(windows)]
fn win_error(context: &str) -> String {
    use windows_sys::Win32::Foundation::GetLastError;
    let code = unsafe { GetLastError() };
    format!("{context} (Windows greška {code})")
}

#[cfg(windows)]
pub fn store_secret(target: &str, username: &str, secret: &str) -> Result<(), String> {
    use std::ptr::null_mut;
    use windows_sys::Win32::{
        Foundation::FILETIME,
        Security::Credentials::{
            CRED_MAX_CREDENTIAL_BLOB_SIZE, CRED_PERSIST_LOCAL_MACHINE, CRED_TYPE_GENERIC,
            CREDENTIALW, CredWriteW,
        },
    };

    let bytes = secret.as_bytes();
    if bytes.is_empty()
        || bytes.len() > MAX_SECRET_BYTES
        || bytes.len() > CRED_MAX_CREDENTIAL_BLOB_SIZE as usize
    {
        return Err("Lozinka nije valjane duljine".into());
    }
    if target.len() > 512 || username.len() > 2_048 {
        return Err("Podaci vjerodajnice su predugački".into());
    }

    let mut target_w = to_wide(target);
    let mut user_w = to_wide(username);
    let mut blob = bytes.to_vec();

    let credential = CREDENTIALW {
        Flags: 0,
        Type: CRED_TYPE_GENERIC,
        TargetName: target_w.as_mut_ptr(),
        Comment: null_mut(),
        LastWritten: FILETIME {
            dwLowDateTime: 0,
            dwHighDateTime: 0,
        },
        CredentialBlobSize: blob.len() as u32,
        CredentialBlob: blob.as_mut_ptr(),
        Persist: CRED_PERSIST_LOCAL_MACHINE,
        AttributeCount: 0,
        Attributes: null_mut(),
        TargetAlias: null_mut(),
        UserName: user_w.as_mut_ptr(),
    };

    let ok = unsafe { CredWriteW(&credential, 0) };
    blob.fill(0);
    if ok == 0 {
        return Err(win_error(
            "Windows nije mogao sigurno spremiti vjerodajnicu",
        ));
    }
    Ok(())
}

#[cfg(not(windows))]
pub fn store_secret(_target: &str, _username: &str, _secret: &str) -> Result<(), String> {
    Err("Sigurni spremnik je dostupan samo na Windowsu".into())
}

#[cfg(windows)]
pub fn read_secret(target: &str) -> Result<String, String> {
    use std::{ptr::null_mut, slice};
    use windows_sys::Win32::Security::Credentials::{
        CRED_TYPE_GENERIC, CREDENTIALW, CredFree, CredReadW,
    };

    let target_w = to_wide(target);
    let mut credential: *mut CREDENTIALW = null_mut();
    let ok = unsafe { CredReadW(target_w.as_ptr(), CRED_TYPE_GENERIC, 0, &mut credential) };
    if ok == 0 || credential.is_null() {
        return Err(win_error("Vjerodajnica nije pronađena"));
    }

    let result = unsafe {
        let item = &*credential;
        if item.CredentialBlob.is_null() || item.CredentialBlobSize == 0 {
            Err("Spremljena vjerodajnica je prazna".to_string())
        } else {
            let bytes = slice::from_raw_parts(
                item.CredentialBlob as *const u8,
                item.CredentialBlobSize as usize,
            );
            String::from_utf8(bytes.to_vec())
                .map_err(|_| "Spremljena vjerodajnica nije valjana".to_string())
        }
    };
    unsafe { CredFree(credential.cast()) };
    result
}

#[cfg(not(windows))]
pub fn read_secret(_target: &str) -> Result<String, String> {
    Err("Sigurni spremnik je dostupan samo na Windowsu".into())
}

#[cfg(windows)]
pub fn delete_secret(target: &str) -> Result<(), String> {
    use windows_sys::Win32::{
        Foundation::{ERROR_NOT_FOUND, GetLastError},
        Security::Credentials::{CRED_TYPE_GENERIC, CredDeleteW},
    };

    let target_w = to_wide(target);
    let ok = unsafe { CredDeleteW(target_w.as_ptr(), CRED_TYPE_GENERIC, 0) };
    if ok == 0 {
        let code = unsafe { GetLastError() };
        if code != ERROR_NOT_FOUND {
            return Err(format!(
                "Windows nije mogao obrisati vjerodajnicu (greška {code})"
            ));
        }
    }
    Ok(())
}

#[cfg(not(windows))]
pub fn delete_secret(_target: &str) -> Result<(), String> {
    Ok(())
}

pub fn mail_secret_target(account_id: &str) -> String {
    format!("{MAIL_PREFIX}{account_id}")
}

fn vault_secret_target(id: &str) -> String {
    format!("{VAULT_PREFIX}{id}")
}

#[tauri::command]
pub async fn vault_list(store: State<'_, ProfileStore>) -> Result<Vec<VaultEntry>, String> {
    Ok(store.list_vault())
}

#[tauri::command]
pub async fn vault_save(
    store: State<'_, ProfileStore>,
    id: Option<String>,
    origin: String,
    username: String,
    password: String,
    label: String,
) -> Result<VaultEntry, String> {
    let origin = normalize_origin(&origin)?;

    if let Some(id) = id {
        Uuid::parse_str(&id).map_err(|_| "ID spremljene prijave nije valjan".to_string())?;
        let existing = store.get_vault(&id).ok_or("Lozinka nije pronađena")?;
        let target = vault_secret_target(&id);
        let old_secret = read_secret(&target)?;
        store_secret(&target, &username, &password)?;

        match store.upsert_vault_metadata(Some(id.clone()), &origin, &username, &label) {
            Ok(entry) => Ok(entry),
            Err(error) => {
                let _ = store_secret(&target, &existing.username, &old_secret);
                Err(error)
            }
        }
    } else {
        let entry = store.upsert_vault_metadata(None, &origin, &username, &label)?;
        if let Err(error) = store_secret(&vault_secret_target(&entry.id), &username, &password) {
            let _ = store.remove_vault_metadata(&entry.id);
            return Err(error);
        }
        Ok(entry)
    }
}

#[tauri::command]
pub async fn vault_delete(store: State<'_, ProfileStore>, id: String) -> Result<bool, String> {
    Uuid::parse_str(&id).map_err(|_| "ID spremljene prijave nije valjan".to_string())?;
    if store.get_vault(&id).is_none() {
        return Ok(false);
    }
    delete_secret(&vault_secret_target(&id))?;
    store.remove_vault_metadata(&id)
}

#[tauri::command]
pub async fn vault_fill(
    app: AppHandle,
    store: State<'_, ProfileStore>,
    id: String,
    tab_id: String,
) -> Result<(), String> {
    Uuid::parse_str(&id).map_err(|_| "ID spremljene prijave nije valjan".to_string())?;
    Uuid::parse_str(&tab_id).map_err(|_| "ID taba nije valjan".to_string())?;

    let entry = store.get_vault(&id).ok_or("Lozinka nije pronađena")?;
    let webview = app
        .get_webview(&format!("tab-{tab_id}"))
        .ok_or("Web-stranica nije aktivna")?;
    let current_url = webview
        .url()
        .map_err(|error| error.to_string())?
        .to_string();
    let current_origin = normalize_origin(&current_url)?;
    if current_origin != entry.origin {
        return Err("Spremljena prijava pripada drugoj domeni".into());
    }

    let password = read_secret(&vault_secret_target(&id))?;
    let username_json =
        serde_json::to_string(&entry.username).map_err(|error| error.to_string())?;
    let password_json = serde_json::to_string(&password).map_err(|error| error.to_string())?;

    let script = format!(
        r#"(() => {{
          'use strict';
          const username = {username_json};
          const password = {password_json};
          const setValue = (el, value) => {{
            if (!el) return;
            const proto = el instanceof HTMLTextAreaElement
              ? HTMLTextAreaElement.prototype
              : HTMLInputElement.prototype;
            const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
            if (setter) setter.call(el, value); else el.value = value;
            el.dispatchEvent(new Event('input', {{ bubbles: true }}));
            el.dispatchEvent(new Event('change', {{ bubbles: true }}));
          }};
          const passwordInput = document.querySelector('input[type="password"]:not([disabled])');
          if (!passwordInput) return;
          const root = passwordInput.form || document;
          const usernameInput = root.querySelector(
            'input[autocomplete="username"], input[type="email"], input[name*="user" i], input[name*="email" i], input[id*="user" i], input[id*="email" i], input[type="text"]'
          );
          setValue(usernameInput, username);
          setValue(passwordInput, password);
          passwordInput.focus();
        }})();"#
    );

    webview.eval(&script).map_err(|error| error.to_string())
}
