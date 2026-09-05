use crate::privacy::{PrivacyEngine, DOCUMENT_START_SCRIPT};
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tauri::{
    AppHandle, Emitter, LogicalPosition, LogicalSize, Manager, State, WebviewBuilder, WebviewUrl,
    webview::{NewWindowResponse, PageLoadEvent},
};
use url::Url;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TabSnapshot {
    pub id: String,
    pub title: String,
    pub url: Option<String>,
    pub loading: bool,
    pub blocked: u64,
    pub has_webview: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct TabEvent {
    id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    loading: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    blocked: Option<u64>,
}

#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContentBounds {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

impl Default for ContentBounds {
    fn default() -> Self {
        Self { x: 0.0, y: 96.0, width: 1200.0, height: 704.0 }
    }
}

#[derive(Debug, Clone)]
struct TabRecord {
    snapshot: TabSnapshot,
    webview_label: Option<String>,
}

pub struct BrowserState {
    tabs: Mutex<HashMap<String, TabRecord>>,
    active: Mutex<Option<String>>,
    bounds: Mutex<ContentBounds>,
    pub privacy: PrivacyEngine,
}

impl BrowserState {
    pub fn new() -> Self {
        Self {
            tabs: Mutex::new(HashMap::new()),
            active: Mutex::new(None),
            bounds: Mutex::new(ContentBounds::default()),
            privacy: PrivacyEngine::new(),
        }
    }

    pub fn increment_blocked(&self, tab_id: &str) -> Option<u64> {
        let mut tabs = self.tabs.lock();
        let record = tabs.get_mut(tab_id)?;
        record.snapshot.blocked = record.snapshot.blocked.saturating_add(1);
        Some(record.snapshot.blocked)
    }
}

fn validate_tab_id(tab_id: &str) -> Result<(), String> {
    if tab_id.len() != 36 || !tab_id.chars().all(|c| c.is_ascii_hexdigit() || c == '-') {
        return Err("Neispravan ID taba".into());
    }
    Ok(())
}

fn validate_url(input: &str) -> Result<Url, String> {
    let mut url = Url::parse(input).map_err(|_| "Neispravna web-adresa".to_string())?;
    if !matches!(url.scheme(), "http" | "https") {
        return Err("Ghost Browser dopušta samo HTTP i HTTPS navigaciju".into());
    }
    if url.host_str().is_none() {
        return Err("Web-adresa nema valjanu domenu".into());
    }
    if !url.username().is_empty() || url.password().is_some() {
        return Err("Korisnički podaci unutar URL-a nisu dopušteni".into());
    }

    const TRACKING: &[&str] = &[
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid"
    ];
    let pairs: Vec<(String, String)> = url.query_pairs()
        .filter(|(key, _)| !TRACKING.iter().any(|blocked| key.eq_ignore_ascii_case(blocked)))
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    if url.query().is_some() {
        url.set_query(None);
        if !pairs.is_empty() {
            url.query_pairs_mut().extend_pairs(pairs);
        }
    }
    Ok(url)
}

#[tauri::command]
pub async fn create_tab(state: State<'_, BrowserState>) -> Result<TabSnapshot, String> {
    let id = Uuid::new_v4().to_string();
    let snapshot = TabSnapshot {
        id: id.clone(),
        title: "Novi tab".into(),
        url: None,
        loading: false,
        blocked: 0,
        has_webview: false,
    };
    state.tabs.lock().insert(id.clone(), TabRecord { snapshot: snapshot.clone(), webview_label: None });
    *state.active.lock() = Some(id);
    Ok(snapshot)
}

#[tauri::command]
pub async fn set_active_tab(app: AppHandle, state: State<'_, BrowserState>, tab_id: String) -> Result<(), String> {
    validate_tab_id(&tab_id)?;
    if !state.tabs.lock().contains_key(&tab_id) {
        return Err("Tab ne postoji".into());
    }
    *state.active.lock() = Some(tab_id.clone());
    for (label, webview) in app.webviews() {
        if !label.starts_with("tab-") { continue; }
        if label == format!("tab-{tab_id}") {
            webview.show().map_err(|e| e.to_string())?;
            let _ = webview.set_focus();
        } else {
            let _ = webview.hide();
        }
    }
    Ok(())
}

#[tauri::command]
pub async fn navigate_tab(app: AppHandle, state: State<'_, BrowserState>, tab_id: String, target: String) -> Result<(), String> {
    validate_tab_id(&tab_id)?;
    let target = validate_url(&target)?;
    let existing_label = state.tabs.lock().get(&tab_id).and_then(|record| record.webview_label.clone());
    if let Some(label) = existing_label {
        let webview = app.get_webview(&label).ok_or("WebView taba nije pronađen")?;
        webview.navigate(target).map_err(|e| e.to_string())?;
        return Ok(());
    }

    let window = app.get_window("main").ok_or("Glavni prozor nije pronađen")?;
    let bounds = *state.bounds.lock();
    let label = format!("tab-{tab_id}");
    let tab_for_load = tab_id.clone();
    let tab_for_title = tab_id.clone();
    let tab_for_download = tab_id.clone();

    let builder = WebviewBuilder::new(label.clone(), WebviewUrl::External(target.clone()))
        .initialization_script_for_all_frames(DOCUMENT_START_SCRIPT)
        .general_autofill_enabled(false)
        .zoom_hotkeys_enabled(true)
        .on_navigation(|url| matches!(url.scheme(), "http" | "https"))
        .on_new_window(|_url, _features| NewWindowResponse::Deny)
        .on_page_load(move |webview, payload| {
            let loading = matches!(payload.event(), PageLoadEvent::Started);
            let url = payload.url().to_string();
            if let Some(state) = webview.try_state::<BrowserState>() {
                if let Some(record) = state.tabs.lock().get_mut(&tab_for_load) {
                    record.snapshot.loading = loading;
                    record.snapshot.url = Some(url.clone());
                    record.snapshot.has_webview = true;
                }
            }
            let _ = webview.emit_to("main", "ghost://tab-event", TabEvent {
                id: tab_for_load.clone(), title: None, url: Some(url), loading: Some(loading), blocked: None,
            });
        })
        .on_document_title_changed(move |webview, title| {
            if let Some(state) = webview.try_state::<BrowserState>() {
                if let Some(record) = state.tabs.lock().get_mut(&tab_for_title) {
                    record.snapshot.title = if title.trim().is_empty() { "Novi tab".into() } else { title.clone() };
                }
            }
            let _ = webview.emit_to("main", "ghost://tab-event", TabEvent {
                id: tab_for_title.clone(), title: Some(title), url: None, loading: None, blocked: None,
            });
        })
        .on_download(move |webview, event| {
            use tauri::webview::DownloadEvent;
            if let DownloadEvent::Requested { url, .. } = event {
                let _ = webview.emit_to("main", "ghost://download", serde_json::json!({
                    "tabId": tab_for_download,
                    "url": url.to_string()
                }));
            }
            true
        });

    let webview = window.add_child(
        builder,
        LogicalPosition::new(bounds.x, bounds.y),
        LogicalSize::new(bounds.width.max(1.0), bounds.height.max(1.0)),
    ).map_err(|e| e.to_string())?;

    #[cfg(windows)]
    crate::webview2_guard::install(&webview, tab_id.clone(), app.clone())?;

    {
        let mut tabs = state.tabs.lock();
        let record = tabs.get_mut(&tab_id).ok_or("Tab je zatvoren tijekom inicijalizacije")?;
        record.webview_label = Some(label);
        record.snapshot.url = Some(target.to_string());
        record.snapshot.loading = true;
        record.snapshot.has_webview = true;
    }

    set_active_tab(app, state, tab_id).await
}

#[tauri::command]
pub async fn close_tab(app: AppHandle, state: State<'_, BrowserState>, tab_id: String) -> Result<(), String> {
    validate_tab_id(&tab_id)?;
    let record = state.tabs.lock().remove(&tab_id);
    if let Some(record) = record {
        if let Some(label) = record.webview_label {
            if let Some(webview) = app.get_webview(&label) {
                webview.close().map_err(|e| e.to_string())?;
            }
        }
    }
    if state.active.lock().as_deref() == Some(tab_id.as_str()) {
        *state.active.lock() = None;
    }
    Ok(())
}

fn tab_webview(app: &AppHandle, state: &BrowserState, tab_id: &str) -> Result<tauri::Webview, String> {
    validate_tab_id(tab_id)?;
    let label = state.tabs.lock().get(tab_id)
        .and_then(|record| record.webview_label.clone())
        .ok_or("Tab još nema otvorenu web-stranicu")?;
    app.get_webview(&label).ok_or_else(|| "WebView taba nije pronađen".into())
}

#[tauri::command]
pub async fn reload_tab(app: AppHandle, state: State<'_, BrowserState>, tab_id: String) -> Result<(), String> {
    tab_webview(&app, &state, &tab_id)?.reload().map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn go_back(app: AppHandle, state: State<'_, BrowserState>, tab_id: String) -> Result<(), String> {
    let webview = tab_webview(&app, &state, &tab_id)?;
    #[cfg(windows)]
    return crate::webview2_guard::go_back(&webview);
    #[allow(unreachable_code)]
    Ok(())
}

#[tauri::command]
pub async fn go_forward(app: AppHandle, state: State<'_, BrowserState>, tab_id: String) -> Result<(), String> {
    let webview = tab_webview(&app, &state, &tab_id)?;
    #[cfg(windows)]
    return crate::webview2_guard::go_forward(&webview);
    #[allow(unreachable_code)]
    Ok(())
}

#[tauri::command]
pub async fn sync_viewport(app: AppHandle, state: State<'_, BrowserState>, x: f64, y: f64, width: f64, height: f64) -> Result<(), String> {
    let bounds = ContentBounds { x: x.max(0.0), y: y.max(0.0), width: width.max(1.0), height: height.max(1.0) };
    *state.bounds.lock() = bounds;
    for (label, webview) in app.webviews() {
        if !label.starts_with("tab-") { continue; }
        webview.set_position(LogicalPosition::new(bounds.x, bounds.y)).map_err(|e| e.to_string())?;
        webview.set_size(LogicalSize::new(bounds.width, bounds.height)).map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
pub async fn clear_browsing_data(app: AppHandle, state: State<'_, BrowserState>) -> Result<(), String> {
    for (label, webview) in app.webviews() {
        if label.starts_with("tab-") {
            webview.clear_all_browsing_data().map_err(|e| e.to_string())?;
        }
    }
    for record in state.tabs.lock().values_mut() {
        record.snapshot.blocked = 0;
    }
    Ok(())
}
