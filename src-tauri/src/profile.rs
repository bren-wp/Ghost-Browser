use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use std::{
    env,
    fs,
    io::Write,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};
use url::Url;
use uuid::Uuid;

const PROFILE_VERSION: u32 = 1;
const MAX_BOOKMARKS: usize = 5_000;
const MAX_HISTORY: usize = 10_000;
const MAX_DOWNLOADS: usize = 2_000;
const MAX_VAULT_ENTRIES: usize = 500;
const MAX_MAIL_ACCOUNTS: usize = 20;
const MAX_TEXT: usize = 2_048;
const MAX_URL: usize = 8_192;

// Serializes filesystem operations even if more than one ProfileStore is ever
// created in-process. The application normally owns one managed store, but this
// also prevents temp/backup rename races in tests and defensive recovery paths.
static PROFILE_IO_LOCK: Mutex<()> = Mutex::new(());

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Bookmark {
    pub id: String,
    pub title: String,
    pub url: String,
    pub created_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryEntry {
    pub id: String,
    pub title: String,
    pub url: String,
    pub visited_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadEntry {
    pub id: String,
    pub url: String,
    pub started_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VaultEntry {
    pub id: String,
    pub origin: String,
    pub username: String,
    pub label: String,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MailAccount {
    pub id: String,
    pub email: String,
    pub display_name: String,
    pub imap_host: String,
    pub imap_port: u16,
    pub smtp_host: String,
    pub smtp_port: u16,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ProfileData {
    version: u32,
    bookmarks: Vec<Bookmark>,
    history: Vec<HistoryEntry>,
    downloads: Vec<DownloadEntry>,
    vault: Vec<VaultEntry>,
    mail_accounts: Vec<MailAccount>,
}

impl Default for ProfileData {
    fn default() -> Self {
        Self {
            version: PROFILE_VERSION,
            bookmarks: Vec::new(),
            history: Vec::new(),
            downloads: Vec::new(),
            vault: Vec::new(),
            mail_accounts: Vec::new(),
        }
    }
}

pub struct ProfileStore {
    path: PathBuf,
    data: Mutex<ProfileData>,
}

fn now_epoch() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn profile_path() -> PathBuf {
    let base = env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(env::temp_dir);
    base.join("Ghost Browser").join("Profile").join("profile.json")
}

fn sanitize_text(input: &str, field: &str) -> Result<String, String> {
    let value = input.trim();
    if value.is_empty() {
        return Err(format!("{field} ne smije biti prazan"));
    }
    if value.len() > MAX_TEXT || value.chars().any(char::is_control) {
        return Err(format!("{field} nije valjan"));
    }
    Ok(value.to_string())
}

fn normalize_http_url(input: &str) -> Result<String, String> {
    if input.len() > MAX_URL || input.chars().any(char::is_control) {
        return Err("Web-adresa nije valjana".into());
    }
    let url = Url::parse(input).map_err(|_| "Web-adresa nije valjana".to_string())?;
    if !matches!(url.scheme(), "http" | "https")
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
    {
        return Err("Dopuštene su samo valjane HTTP i HTTPS adrese bez vjerodajnica".into());
    }
    Ok(url.to_string())
}

pub fn normalize_origin(input: &str) -> Result<String, String> {
    let url = Url::parse(input).map_err(|_| "Domena nije valjana".to_string())?;
    if !matches!(url.scheme(), "http" | "https") || url.host_str().is_none() {
        return Err("Domena nije valjana".into());
    }
    let host = url.host_str().unwrap_or_default();
    let port = url.port().map(|value| format!(":{value}")).unwrap_or_default();
    Ok(format!("{}://{}{}", url.scheme(), host.to_ascii_lowercase(), port))
}

fn write_atomic(path: &Path, data: &[u8]) -> Result<(), String> {
    let _io_guard = PROFILE_IO_LOCK.lock();
    let parent = path.parent().ok_or("Putanja profila nije valjana")?;
    fs::create_dir_all(parent).map_err(|error| error.to_string())?;

    let temp = path.with_extension("json.tmp");
    let backup = path.with_extension("json.bak");
    {
        let mut file = fs::File::create(&temp).map_err(|error| error.to_string())?;
        file.write_all(data).map_err(|error| error.to_string())?;
        file.sync_all().map_err(|error| error.to_string())?;
    }

    if path.exists() {
        let _ = fs::remove_file(&backup);
        fs::rename(path, &backup).map_err(|error| error.to_string())?;
    }

    if let Err(error) = fs::rename(&temp, path) {
        if backup.exists() && !path.exists() {
            let _ = fs::rename(&backup, path);
        }
        return Err(error.to_string());
    }

    let _ = fs::remove_file(&backup);
    Ok(())
}

fn parse_profile(bytes: &[u8]) -> Option<ProfileData> {
    let mut data = serde_json::from_slice::<ProfileData>(bytes).ok()?;
    data.version = PROFILE_VERSION;
    Some(data)
}

fn restore_backup_unlocked(path: &Path) -> Option<ProfileData> {
    let backup = path.with_extension("json.bak");
    let bytes = fs::read(&backup).ok()?;
    let data = parse_profile(&bytes)?;

    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if fs::copy(&backup, path).is_ok() {
        let _ = fs::remove_file(&backup);
    }
    Some(data)
}

fn load_profile(path: &Path) -> ProfileData {
    let _io_guard = PROFILE_IO_LOCK.lock();
    match fs::read(path) {
        Ok(bytes) => {
            if let Some(data) = parse_profile(&bytes) {
                return data;
            }

            let corrupt = path.with_extension(format!("corrupt-{}.json", now_epoch()));
            let _ = fs::rename(path, corrupt);
        }
        Err(_) => {}
    }

    restore_backup_unlocked(path).unwrap_or_default()
}

impl ProfileStore {
    pub fn new() -> Self {
        Self::from_path(profile_path())
    }

    fn from_path(path: PathBuf) -> Self {
        let data = load_profile(&path);
        Self {
            path,
            data: Mutex::new(data),
        }
    }

    #[cfg(test)]
    pub(crate) fn new_for_test(path: PathBuf) -> Self {
        Self::from_path(path)
    }

    fn persist_locked(&self, data: &ProfileData) -> Result<(), String> {
        let encoded = serde_json::to_vec_pretty(data).map_err(|error| error.to_string())?;
        write_atomic(&self.path, &encoded)
    }

    pub fn list_bookmarks(&self) -> Vec<Bookmark> {
        self.data.lock().bookmarks.clone()
    }

    pub fn add_bookmark(&self, title: &str, url: &str) -> Result<Bookmark, String> {
        let title = sanitize_text(title, "Naslov")?;
        let url = normalize_http_url(url)?;
        let mut data = self.data.lock();

        if let Some(existing) = data.bookmarks.iter_mut().find(|item| item.url == url) {
            existing.title = title;
            let result = existing.clone();
            self.persist_locked(&data)?;
            return Ok(result);
        }

        if data.bookmarks.len() >= MAX_BOOKMARKS {
            return Err("Dosegnut je limit favorita".into());
        }

        let item = Bookmark {
            id: Uuid::new_v4().to_string(),
            title,
            url,
            created_at: now_epoch(),
        };
        data.bookmarks.insert(0, item.clone());
        self.persist_locked(&data)?;
        Ok(item)
    }

    pub fn remove_bookmark(&self, id: &str) -> Result<bool, String> {
        let mut data = self.data.lock();
        let before = data.bookmarks.len();
        data.bookmarks.retain(|item| item.id != id);
        let changed = before != data.bookmarks.len();
        if changed {
            self.persist_locked(&data)?;
        }
        Ok(changed)
    }

    pub fn record_history(&self, title: &str, url: &str) -> Result<(), String> {
        let title = sanitize_text(if title.trim().is_empty() { url } else { title }, "Naslov")?;
        let url = normalize_http_url(url)?;
        let now = now_epoch();
        let mut data = self.data.lock();

        if let Some(existing) = data.history.iter_mut().find(|item| item.url == url) {
            existing.title = title;
            existing.visited_at = now;
            let existing = existing.clone();
            data.history.retain(|item| item.id != existing.id);
            data.history.insert(0, existing);
        } else {
            data.history.insert(
                0,
                HistoryEntry {
                    id: Uuid::new_v4().to_string(),
                    title,
                    url,
                    visited_at: now,
                },
            );
        }

        data.history.truncate(MAX_HISTORY);
        self.persist_locked(&data)
    }

    pub fn list_history(&self, limit: usize) -> Vec<HistoryEntry> {
        self.data
            .lock()
            .history
            .iter()
            .take(limit.min(MAX_HISTORY))
            .cloned()
            .collect()
    }

    pub fn clear_history(&self) -> Result<(), String> {
        let mut data = self.data.lock();
        data.history.clear();
        self.persist_locked(&data)
    }

    pub fn record_download(&self, url: &str) -> Result<(), String> {
        let url = normalize_http_url(url)?;
        let mut data = self.data.lock();
        data.downloads.insert(
            0,
            DownloadEntry {
                id: Uuid::new_v4().to_string(),
                url,
                started_at: now_epoch(),
            },
        );
        data.downloads.truncate(MAX_DOWNLOADS);
        self.persist_locked(&data)
    }

    pub fn list_downloads(&self, limit: usize) -> Vec<DownloadEntry> {
        self.data
            .lock()
            .downloads
            .iter()
            .take(limit.min(MAX_DOWNLOADS))
            .cloned()
            .collect()
    }

    pub fn clear_downloads(&self) -> Result<(), String> {
        let mut data = self.data.lock();
        data.downloads.clear();
        self.persist_locked(&data)
    }

    pub fn list_vault(&self) -> Vec<VaultEntry> {
        self.data.lock().vault.clone()
    }

    pub fn upsert_vault_metadata(
        &self,
        id: Option<String>,
        origin: &str,
        username: &str,
        label: &str,
    ) -> Result<VaultEntry, String> {
        let origin = normalize_origin(origin)?;
        let username = sanitize_text(username, "Korisničko ime")?;
        let label = if label.trim().is_empty() {
            origin.clone()
        } else {
            sanitize_text(label, "Naziv")?
        };
        let now = now_epoch();
        let mut data = self.data.lock();

        if let Some(id) = id {
            let existing = data
                .vault
                .iter_mut()
                .find(|item| item.id == id)
                .ok_or("Lozinka nije pronađena")?;
            existing.origin = origin;
            existing.username = username;
            existing.label = label;
            existing.updated_at = now;
            let result = existing.clone();
            self.persist_locked(&data)?;
            return Ok(result);
        }

        if data.vault.len() >= MAX_VAULT_ENTRIES {
            return Err("Dosegnut je limit spremljenih prijava".into());
        }

        let item = VaultEntry {
            id: Uuid::new_v4().to_string(),
            origin,
            username,
            label,
            created_at: now,
            updated_at: now,
        };
        data.vault.insert(0, item.clone());
        self.persist_locked(&data)?;
        Ok(item)
    }

    pub fn get_vault(&self, id: &str) -> Option<VaultEntry> {
        self.data.lock().vault.iter().find(|item| item.id == id).cloned()
    }

    pub fn remove_vault_metadata(&self, id: &str) -> Result<bool, String> {
        let mut data = self.data.lock();
        let before = data.vault.len();
        data.vault.retain(|item| item.id != id);
        let changed = before != data.vault.len();
        if changed {
            self.persist_locked(&data)?;
        }
        Ok(changed)
    }

    pub fn list_mail_accounts(&self) -> Vec<MailAccount> {
        self.data.lock().mail_accounts.clone()
    }

    pub fn add_mail_account(
        &self,
        email: &str,
        display_name: &str,
        imap_host: &str,
        imap_port: u16,
        smtp_host: &str,
        smtp_port: u16,
    ) -> Result<MailAccount, String> {
        let email = sanitize_text(email, "E-mail")?;
        if !email.contains('@') {
            return Err("E-mail adresa nije valjana".into());
        }
        let display_name = sanitize_text(display_name, "Naziv računa")?;
        let imap_host = sanitize_text(imap_host, "IMAP poslužitelj")?;
        let smtp_host = sanitize_text(smtp_host, "SMTP poslužitelj")?;
        if imap_port == 0 || smtp_port == 0 {
            return Err("Port nije valjan".into());
        }

        let now = now_epoch();
        let mut data = self.data.lock();
        if data.mail_accounts.len() >= MAX_MAIL_ACCOUNTS {
            return Err("Dosegnut je limit mail računa".into());
        }
        if data.mail_accounts.iter().any(|item| item.email.eq_ignore_ascii_case(&email)) {
            return Err("Ovaj mail račun već postoji".into());
        }

        let account = MailAccount {
            id: Uuid::new_v4().to_string(),
            email,
            display_name,
            imap_host,
            imap_port,
            smtp_host,
            smtp_port,
            created_at: now,
            updated_at: now,
        };
        data.mail_accounts.push(account.clone());
        self.persist_locked(&data)?;
        Ok(account)
    }

    pub fn get_mail_account(&self, id: &str) -> Option<MailAccount> {
        self.data
            .lock()
            .mail_accounts
            .iter()
            .find(|item| item.id == id)
            .cloned()
    }

    pub fn remove_mail_account(&self, id: &str) -> Result<bool, String> {
        let mut data = self.data.lock();
        let before = data.mail_accounts.len();
        data.mail_accounts.retain(|item| item.id != id);
        let changed = before != data.mail_accounts.len();
        if changed {
            self.persist_locked(&data)?;
        }
        Ok(changed)
    }
}

#[tauri::command]
pub async fn list_bookmarks(store: tauri::State<'_, ProfileStore>) -> Result<Vec<Bookmark>, String> {
    Ok(store.list_bookmarks())
}

#[tauri::command]
pub async fn add_bookmark(
    store: tauri::State<'_, ProfileStore>,
    title: String,
    url: String,
) -> Result<Bookmark, String> {
    store.add_bookmark(&title, &url)
}

#[tauri::command]
pub async fn remove_bookmark(
    store: tauri::State<'_, ProfileStore>,
    id: String,
) -> Result<bool, String> {
    store.remove_bookmark(&id)
}

#[tauri::command]
pub async fn record_history(
    store: tauri::State<'_, ProfileStore>,
    title: String,
    url: String,
) -> Result<(), String> {
    store.record_history(&title, &url)
}

#[tauri::command]
pub async fn list_history(
    store: tauri::State<'_, ProfileStore>,
    limit: Option<usize>,
) -> Result<Vec<HistoryEntry>, String> {
    Ok(store.list_history(limit.unwrap_or(200)))
}

#[tauri::command]
pub async fn clear_history(store: tauri::State<'_, ProfileStore>) -> Result<(), String> {
    store.clear_history()
}

#[tauri::command]
pub async fn record_download(
    store: tauri::State<'_, ProfileStore>,
    url: String,
) -> Result<(), String> {
    store.record_download(&url)
}

#[tauri::command]
pub async fn list_downloads(
    store: tauri::State<'_, ProfileStore>,
    limit: Option<usize>,
) -> Result<Vec<DownloadEntry>, String> {
    Ok(store.list_downloads(limit.unwrap_or(200)))
}

#[tauri::command]
pub async fn clear_downloads(store: tauri::State<'_, ProfileStore>) -> Result<(), String> {
    store.clear_downloads()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_profile_path(name: &str) -> PathBuf {
        env::temp_dir()
            .join(format!("ghost-browser-{name}-{}", Uuid::new_v4()))
            .join("profile.json")
    }

    fn sample_profile() -> ProfileData {
        ProfileData {
            version: PROFILE_VERSION,
            bookmarks: vec![Bookmark {
                id: Uuid::new_v4().to_string(),
                title: "Ghost test".into(),
                url: "https://example.com/".into(),
                created_at: 1,
            }],
            ..ProfileData::default()
        }
    }

    #[test]
    fn origin_is_reduced_to_scheme_host_and_port() {
        assert_eq!(
            normalize_origin("https://Example.com:8443/login?a=1").unwrap(),
            "https://example.com:8443"
        );
    }

    #[test]
    fn credential_urls_are_rejected() {
        assert!(normalize_http_url("https://user:pass@example.com/").is_err());
    }

    #[test]
    fn javascript_urls_are_rejected() {
        assert!(normalize_http_url("javascript:alert(1)").is_err());
    }

    #[test]
    fn missing_primary_profile_recovers_from_valid_backup() {
        let path = temp_profile_path("backup-missing-primary");
        let parent = path.parent().unwrap();
        fs::create_dir_all(parent).unwrap();
        let backup = path.with_extension("json.bak");
        fs::write(&backup, serde_json::to_vec_pretty(&sample_profile()).unwrap()).unwrap();

        let loaded = load_profile(&path);
        assert_eq!(loaded.bookmarks.len(), 1);
        assert!(path.exists());
        assert!(!backup.exists());

        let _ = fs::remove_dir_all(parent.parent().unwrap_or(parent));
    }

    #[test]
    fn corrupt_primary_profile_recovers_from_valid_backup() {
        let path = temp_profile_path("backup-corrupt-primary");
        let parent = path.parent().unwrap();
        fs::create_dir_all(parent).unwrap();
        fs::write(&path, b"{not valid json").unwrap();
        let backup = path.with_extension("json.bak");
        fs::write(&backup, serde_json::to_vec_pretty(&sample_profile()).unwrap()).unwrap();

        let loaded = load_profile(&path);
        assert_eq!(loaded.bookmarks.len(), 1);
        assert!(path.exists());
        assert!(!backup.exists());

        let _ = fs::remove_dir_all(parent.parent().unwrap_or(parent));
    }
}
