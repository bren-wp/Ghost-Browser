use crate::privacy::{PrivacyEngine, DOCUMENT_START_SCRIPT};
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::atomic::{AtomicU64, Ordering},
};
use tauri::{
    AppHandle, Emitter, LogicalPosition, LogicalSize, Manager, State, Webview, WebviewBuilder,
    WebviewUrl,
    webview::{DownloadEvent, NewWindowResponse, PageLoadEvent},
};
use url::Url;
use uuid::Uuid;

const MAX_URL_LENGTH: usize = 8192;
const MAX_TABS: usize = 512;
const MAX_LIVE_WEBVIEWS: usize = 8;
const PRIVACY_BROWSER_ARGS: &str =
    "--disable-sync --no-first-run --disable-default-apps --disable-domain-reliability --disable-breakpad --disable-crash-reporter";

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TabSnapshot {
    pub id: String,
    pub title: String,
    pub url: Option<String>,
    pub loading: bool,
    pub blocked: u64,
    pub has_webview: bool,
    pub discarded: bool,
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
    #[serde(skip_serializing_if = "Option::is_none")]
    discarded: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BrowserStats {
    pub total_tabs: usize,
    pub live_webviews: usize,
    pub discarded_tabs: usize,
    pub max_live_webviews: usize,
    pub max_tabs: usize,
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
        Self {
            x: 0.0,
            y: 96.0,
            width: 1200.0,
            height: 704.0,
        }
    }
}

#[derive(Debug, Clone)]
struct TabRecord {
    snapshot: TabSnapshot,
    webview_label: Option<String>,
    last_active: u64,
}

pub struct BrowserState {
    tabs: Mutex<HashMap<String, TabRecord>>,
    active: Mutex<Option<String>>,
    bounds: Mutex<ContentBounds>,
    activity_clock: AtomicU64,
    pub privacy: PrivacyEngine,
}

impl BrowserState {
    pub fn new() -> Self {
        Self {
            tabs: Mutex::new(HashMap::new()),
            active: Mutex::new(None),
            bounds: Mutex::new(ContentBounds::default()),
            activity_clock: AtomicU64::new(1),
            privacy: PrivacyEngine::new(),
        }
    }

    fn next_activity(&self) -> u64 {
        self.activity_clock.fetch_add(1, Ordering::Relaxed)
    }

    fn touch_tab(&self, tab_id: &str) {
        let tick = self.next_activity();
        if let Some(record) = self.tabs.lock().get_mut(tab_id) {
            record.last_active = tick;
        }
    }

    pub fn increment_blocked(&self, tab_id: &str) -> Option<u64> {
        let mut tabs = self.tabs.lock();
        let record = tabs.get_mut(tab_id)?;
        record.snapshot.blocked = record.snapshot.blocked.saturating_add(1);
        Some(record.snapshot.blocked)
    }

    pub fn tab_url(&self, tab_id: &str) -> Option<String> {
        self.tabs
            .lock()
            .get(tab_id)
            .and_then(|record| record.snapshot.url.clone())
    }

    pub fn webview_label(&self, tab_id: &str) -> Option<String> {
        self.tabs
            .lock()
            .get(tab_id)
            .and_then(|record| record.webview_label.clone())
    }
}

fn validate_tab_id(tab_id: &str) -> Result<(), String> {
    Uuid::parse_str(tab_id)
        .map(|_| ())
        .map_err(|_| "Neispravan ID taba".to_string())
}

fn is_allowed_http_url(url: &Url) -> bool {
    matches!(url.scheme(), "http" | "https")
        && url.host_str().is_some()
        && url.username().is_empty()
        && url.password().is_none()
        && url.as_str().len() <= MAX_URL_LENGTH
        && !url.as_str().chars().any(char::is_control)
}

fn is_allowed_navigation_url(url: &Url) -> bool {
    if is_allowed_http_url(url) {
        return true;
    }

    if url.as_str().len() > MAX_URL_LENGTH || url.as_str().chars().any(char::is_control) {
        return false;
    }

    match url.scheme() {
        "about" => matches!(url.path(), "blank" | "srcdoc"),
        "blob" => true,
        _ => false,
    }
}

fn persistable_page_url(input: &str) -> Option<String> {
    let url = Url::parse(input).ok()?;
    is_allowed_http_url(&url).then(|| url.to_string())
}

fn validate_url(input: &str) -> Result<Url, String> {
    if input.len() > MAX_URL_LENGTH {
        return Err("Web-adresa je predugačka".into());
    }
    if input.chars().any(char::is_control) {
        return Err("Web-adresa sadrži nedopuštene znakove".into());
    }

    let mut url = Url::parse(input).map_err(|_| "Neispravna web-adresa".to_string())?;
    if !is_allowed_http_url(&url) {
        return Err("Ghost Browser dopušta samo valjane HTTP i HTTPS adrese".into());
    }

    const TRACKING: &[&str] = &[
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "utm_id",
        "fbclid",
        "gclid",
        "dclid",
        "msclkid",
        "mc_cid",
        "mc_eid",
        "igshid",
        "yclid",
        "_hsenc",
        "_hsmi",
        "vero_conv",
        "vero_id",
        "wickedid",
        "twclid",
        "ttclid",
        "gbraid",
        "wbraid",
        "srsltid",
        "gad_source",
        "gad_campaignid",
    ];

    let pairs: Vec<(String, String)> = url
        .query_pairs()
        .filter(|(key, _)| {
            !TRACKING
                .iter()
                .any(|blocked| key.eq_ignore_ascii_case(blocked))
        })
        .map(|(key, value)| (key.into_owned(), value.into_owned()))
        .collect();

    if url.query().is_some() {
        url.set_query(None);
        if !pairs.is_empty() {
            url.query_pairs_mut().extend_pairs(pairs);
        }
    }

    Ok(url)
}

fn live_webview_count(tabs: &HashMap<String, TabRecord>) -> usize {
    tabs.values()
        .filter(|record| record.webview_label.is_some())
        .count()
}

fn select_discard_candidate(
    tabs: &HashMap<String, TabRecord>,
    active_id: Option<&str>,
    keep_id: &str,
) -> Option<String> {
    tabs.iter()
        .filter(|(id, record)| {
            record.webview_label.is_some()
                && id.as_str() != keep_id
                && active_id.is_none_or(|active| id.as_str() != active)
        })
        .min_by_key(|(_, record)| record.last_active)
        .map(|(id, _)| id.clone())
}

fn emit_tab_event(app: &AppHandle, event: TabEvent) {
    let _ = app.emit_to("main", "ghost://tab-event", event);
}

fn discard_tab_webview(
    app: &AppHandle,
    state: &BrowserState,
    tab_id: &str,
) -> Result<bool, String> {
    let label = {
        let mut tabs = state.tabs.lock();
        let Some(record) = tabs.get_mut(tab_id) else {
            return Ok(false);
        };
        let Some(label) = record.webview_label.take() else {
            return Ok(false);
        };

        record.snapshot.has_webview = false;
        record.snapshot.discarded = true;
        record.snapshot.loading = false;
        label
    };

    if let Some(webview) = app.get_webview(&label) {
        webview.close().map_err(|error| error.to_string())?;
    }

    emit_tab_event(
        app,
        TabEvent {
            id: tab_id.to_string(),
            title: None,
            url: None,
            loading: Some(false),
            blocked: None,
            discarded: Some(true),
        },
    );
    Ok(true)
}

fn enforce_live_budget(
    app: &AppHandle,
    state: &BrowserState,
    keep_id: &str,
) -> Result<(), String> {
    loop {
        let active_id = state.active.lock().clone();
        let candidate = {
            let tabs = state.tabs.lock();
            if live_webview_count(&tabs) < MAX_LIVE_WEBVIEWS {
                return Ok(());
            }
            select_discard_candidate(&tabs, active_id.as_deref(), keep_id)
        };

        let Some(candidate) = candidate else {
            return Ok(());
        };
        discard_tab_webview(app, state, &candidate)?;
    }
}

fn show_only_active(app: &AppHandle, active_id: &str) -> Result<(), String> {
    let active_label = format!("tab-{active_id}");
    for (label, webview) in app.webviews() {
        if !label.starts_with("tab-") {
            continue;
        }

        if label == active_label {
            webview.show().map_err(|error| error.to_string())?;
            let _ = webview.set_focus();
        } else {
            let _ = webview.hide();
        }
    }
    Ok(())
}

fn create_webview(
    app: &AppHandle,
    state: &BrowserState,
    tab_id: &str,
    target: Url,
) -> Result<(), String> {
    enforce_live_budget(app, state, tab_id)?;

    let window = app
        .get_window("main")
        .ok_or("Glavni prozor nije pronađen")?;
    let bounds = *state.bounds.lock();
    let label = format!("tab-{tab_id}");
    let tab_for_load = tab_id.to_string();
    let tab_for_title = tab_id.to_string();
    let tab_for_download = tab_id.to_string();
    let tab_for_new_window = tab_id.to_string();
    let label_for_load = label.clone();
    let label_for_title = label.clone();
    let app_for_new_window = app.clone();

    let builder = WebviewBuilder::new(label.clone(), WebviewUrl::External(target.clone()))
        .initialization_script_for_all_frames(DOCUMENT_START_SCRIPT)
        .general_autofill_enabled(false)
        .zoom_hotkeys_enabled(true)
        .additional_browser_args(PRIVACY_BROWSER_ARGS)
        .on_navigation(is_allowed_navigation_url)
        .on_new_window(move |url, _features| {
            if is_allowed_http_url(&url) {
                let _ = app_for_new_window.emit_to(
                    "main",
                    "ghost://open-current-tab",
                    serde_json::json!({
                        "tabId": tab_for_new_window,
                        "url": url.to_string()
                    }),
                );
            }
            NewWindowResponse::Deny
        })
        .on_page_load(move |webview, payload| {
            let loading = matches!(payload.event(), PageLoadEvent::Started);
            let raw_url = payload.url().to_string();
            let persisted_url = persistable_page_url(&raw_url);
            let mut should_emit = false;

            if let Some(state) = webview.try_state::<BrowserState>() {
                if let Some(record) = state.tabs.lock().get_mut(&tab_for_load) {
                    if record.webview_label.as_deref() == Some(label_for_load.as_str()) {
                        record.snapshot.loading = loading;
                        if let Some(url) = persisted_url.as_ref() {
                            record.snapshot.url = Some(url.clone());
                        }
                        record.snapshot.has_webview = true;
                        record.snapshot.discarded = false;
                        should_emit = true;
                    }
                }
            }

            if should_emit {
                let _ = webview.emit_to(
                    "main",
                    "ghost://tab-event",
                    TabEvent {
                        id: tab_for_load.clone(),
                        title: None,
                        url: persisted_url,
                        loading: Some(loading),
                        blocked: None,
                        discarded: Some(false),
                    },
                );
            }
        })
        .on_document_title_changed(move |webview, title| {
            let mut should_emit = false;
            if let Some(state) = webview.try_state::<BrowserState>() {
                if let Some(record) = state.tabs.lock().get_mut(&tab_for_title) {
                    if record.webview_label.as_deref() == Some(label_for_title.as_str()) {
                        record.snapshot.title = if title.trim().is_empty() {
                            "Novi tab".into()
                        } else {
                            title.clone()
                        };
                        should_emit = true;
                    }
                }
            }

            if should_emit {
                let _ = webview.emit_to(
                    "main",
                    "ghost://tab-event",
                    TabEvent {
                        id: tab_for_title.clone(),
                        title: Some(title),
                        url: None,
                        loading: None,
                        blocked: None,
                        discarded: None,
                    },
                );
            }
        })
        .on_download(move |webview, event| match event {
            DownloadEvent::Requested { url, .. } => {
                let allowed = is_allowed_http_url(&url);
                if allowed {
                    let _ = webview.emit_to(
                        "main",
                        "ghost://download",
                        serde_json::json!({
                            "tabId": tab_for_download,
                            "url": url.to_string()
                        }),
                    );
                }
                allowed
            }
            _ => true,
        });

    let webview = window
        .add_child(
            builder,
            LogicalPosition::new(bounds.x, bounds.y),
            LogicalSize::new(bounds.width.max(1.0), bounds.height.max(1.0)),
        )
        .map_err(|error| error.to_string())?;

    #[cfg(windows)]
    if let Err(error) = crate::webview2_guard::install(&webview, tab_id.to_string(), app.clone()) {
        let _ = webview.close();
        return Err(error);
    }

    {
        let mut tabs = state.tabs.lock();
        let record = tabs
            .get_mut(tab_id)
            .ok_or("Tab je zatvoren tijekom inicijalizacije")?;
        record.webview_label = Some(label);
        record.snapshot.url = Some(target.to_string());
        record.snapshot.loading = true;
        record.snapshot.has_webview = true;
        record.snapshot.discarded = false;
    }

    let is_active = state.active.lock().as_deref() == Some(tab_id);
    if is_active {
        webview.show().map_err(|error| error.to_string())?;
        let _ = webview.set_focus();
    } else {
        let _ = webview.hide();
    }

    Ok(())
}

fn webview_or_restore(
    app: &AppHandle,
    state: &BrowserState,
    tab_id: &str,
) -> Result<(Option<Webview>, bool), String> {
    validate_tab_id(tab_id)?;

    let (label, stored_url) = {
        let tabs = state.tabs.lock();
        let record = tabs.get(tab_id).ok_or("Tab ne postoji")?;
        (record.webview_label.clone(), record.snapshot.url.clone())
    };

    if let Some(label) = label {
        if let Some(webview) = app.get_webview(&label) {
            return Ok((Some(webview), false));
        }

        if let Some(record) = state.tabs.lock().get_mut(tab_id) {
            record.webview_label = None;
            record.snapshot.has_webview = false;
            record.snapshot.discarded = true;
        }
    }

    let Some(url) = stored_url else {
        return Ok((None, false));
    };
    let target = validate_url(&url)?;
    create_webview(app, state, tab_id, target)?;
    let label = state
        .tabs
        .lock()
        .get(tab_id)
        .and_then(|record| record.webview_label.clone())
        .ok_or("WebView taba nije obnovljen")?;
    Ok((app.get_webview(&label), true))
}

#[tauri::command]
pub async fn create_tab(state: State<'_, BrowserState>) -> Result<TabSnapshot, String> {
    if state.tabs.lock().len() >= MAX_TABS {
        return Err(format!("Dosegnut je sigurnosni limit od {MAX_TABS} otvorenih tabova"));
    }

    let id = Uuid::new_v4().to_string();
    let snapshot = TabSnapshot {
        id: id.clone(),
        title: "Novi tab".into(),
        url: None,
        loading: false,
        blocked: 0,
        has_webview: false,
        discarded: false,
    };

    state.tabs.lock().insert(
        id,
        TabRecord {
            snapshot: snapshot.clone(),
            webview_label: None,
            last_active: state.next_activity(),
        },
    );
    Ok(snapshot)
}

#[tauri::command]
pub async fn set_active_tab(
    app: AppHandle,
    state: State<'_, BrowserState>,
    tab_id: String,
) -> Result<(), String> {
    validate_tab_id(&tab_id)?;
    if !state.tabs.lock().contains_key(&tab_id) {
        return Err("Tab ne postoji".into());
    }

    let previous = state.active.lock().clone();
    *state.active.lock() = Some(tab_id.clone());
    state.touch_tab(&tab_id);

    if let Err(error) = webview_or_restore(&app, &state, &tab_id) {
        *state.active.lock() = previous.clone();
        if let Some(previous_id) = previous.as_deref() {
            let _ = show_only_active(&app, previous_id);
        }
        return Err(error);
    }

    if let Err(error) = show_only_active(&app, &tab_id) {
        *state.active.lock() = previous.clone();
        if let Some(previous_id) = previous.as_deref() {
            let _ = show_only_active(&app, previous_id);
        }
        return Err(error);
    }

    let _ = app.emit_to(
        "main",
        "ghost://active-tab",
        serde_json::json!({ "id": tab_id }),
    );
    Ok(())
}

#[tauri::command]
pub async fn set_overlay_open(
    app: AppHandle,
    state: State<'_, BrowserState>,
    open: bool,
) -> Result<(), String> {
    let active_id = state.active.lock().clone();
    let Some(active_id) = active_id else {
        return Ok(());
    };

    let label = state
        .tabs
        .lock()
        .get(&active_id)
        .and_then(|record| record.webview_label.clone());

    let Some(label) = label else {
        return Ok(());
    };
    let Some(webview) = app.get_webview(&label) else {
        return Ok(());
    };

    if open {
        webview.hide().map_err(|error| error.to_string())
    } else {
        webview.show().map_err(|error| error.to_string())?;
        let _ = webview.set_focus();
        Ok(())
    }
}

#[tauri::command]
pub async fn navigate_tab(
    app: AppHandle,
    state: State<'_, BrowserState>,
    tab_id: String,
    target: String,
) -> Result<(), String> {
    validate_tab_id(&tab_id)?;
    let target = validate_url(&target)?;

    let existing_label = state
        .tabs
        .lock()
        .get(&tab_id)
        .ok_or("Tab ne postoji")?
        .webview_label
        .clone();

    if let Some(label) = existing_label {
        if let Some(webview) = app.get_webview(&label) {
            {
                let mut tabs = state.tabs.lock();
                if let Some(record) = tabs.get_mut(&tab_id) {
                    record.snapshot.url = Some(target.to_string());
                    record.snapshot.loading = true;
                    record.snapshot.discarded = false;
                }
            }
            state.touch_tab(&tab_id);
            if let Err(error) = webview.navigate(target) {
                if let Some(record) = state.tabs.lock().get_mut(&tab_id) {
                    record.snapshot.loading = false;
                }
                return Err(error.to_string());
            }
            return Ok(());
        }

        if let Some(record) = state.tabs.lock().get_mut(&tab_id) {
            record.webview_label = None;
            record.snapshot.has_webview = false;
            record.snapshot.discarded = true;
        }
    }

    create_webview(&app, &state, &tab_id, target)?;
    state.touch_tab(&tab_id);
    Ok(())
}

#[tauri::command]
pub async fn close_tab(
    app: AppHandle,
    state: State<'_, BrowserState>,
    tab_id: String,
) -> Result<(), String> {
    validate_tab_id(&tab_id)?;
    let record = state.tabs.lock().remove(&tab_id);

    if let Some(record) = record {
        if let Some(label) = record.webview_label {
            if let Some(webview) = app.get_webview(&label) {
                webview.close().map_err(|error| error.to_string())?;
            }
        }
    }

    if state.active.lock().as_deref() == Some(tab_id.as_str()) {
        *state.active.lock() = None;
    }

    Ok(())
}

#[tauri::command]
pub async fn reload_tab(
    app: AppHandle,
    state: State<'_, BrowserState>,
    tab_id: String,
) -> Result<(), String> {
    let (webview, restored) = webview_or_restore(&app, &state, &tab_id)?;
    let Some(webview) = webview else {
        return Ok(());
    };
    if restored {
        return Ok(());
    }
    webview.reload().map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn go_back(
    app: AppHandle,
    state: State<'_, BrowserState>,
    tab_id: String,
) -> Result<(), String> {
    let (webview, restored) = webview_or_restore(&app, &state, &tab_id)?;
    let Some(webview) = webview else {
        return Ok(());
    };
    if restored {
        return Ok(());
    }

    #[cfg(windows)]
    return crate::webview2_guard::go_back(&webview);

    #[allow(unreachable_code)]
    Ok(())
}

#[tauri::command]
pub async fn go_forward(
    app: AppHandle,
    state: State<'_, BrowserState>,
    tab_id: String,
) -> Result<(), String> {
    let (webview, restored) = webview_or_restore(&app, &state, &tab_id)?;
    let Some(webview) = webview else {
        return Ok(());
    };
    if restored {
        return Ok(());
    }

    #[cfg(windows)]
    return crate::webview2_guard::go_forward(&webview);

    #[allow(unreachable_code)]
    Ok(())
}

#[tauri::command]
pub async fn sync_viewport(
    app: AppHandle,
    state: State<'_, BrowserState>,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
) -> Result<(), String> {
    let bounds = ContentBounds {
        x: x.max(0.0),
        y: y.max(0.0),
        width: width.max(1.0),
        height: height.max(1.0),
    };
    *state.bounds.lock() = bounds;

    for (label, webview) in app.webviews() {
        if !label.starts_with("tab-") {
            continue;
        }

        webview
            .set_position(LogicalPosition::new(bounds.x, bounds.y))
            .map_err(|error| error.to_string())?;
        webview
            .set_size(LogicalSize::new(bounds.width, bounds.height))
            .map_err(|error| error.to_string())?;
    }

    Ok(())
}

#[tauri::command]
pub async fn clear_browsing_data(
    app: AppHandle,
    state: State<'_, BrowserState>,
) -> Result<(), String> {
    for (label, webview) in app.webviews() {
        if label.starts_with("tab-") {
            webview
                .clear_all_browsing_data()
                .map_err(|error| error.to_string())?;
        }
    }

    for record in state.tabs.lock().values_mut() {
        record.snapshot.blocked = 0;
    }

    Ok(())
}

#[tauri::command]
pub async fn discard_inactive_tabs(
    app: AppHandle,
    state: State<'_, BrowserState>,
) -> Result<usize, String> {
    let active_id = state.active.lock().clone();
    let mut discarded = 0usize;

    loop {
        let candidate = {
            let tabs = state.tabs.lock();
            if live_webview_count(&tabs) <= 1 {
                break;
            }
            select_discard_candidate(&tabs, active_id.as_deref(), active_id.as_deref().unwrap_or(""))
        };

        let Some(candidate) = candidate else {
            break;
        };
        if discard_tab_webview(&app, &state, &candidate)? {
            discarded += 1;
        }
    }

    Ok(discarded)
}

#[tauri::command]
pub async fn browser_stats(state: State<'_, BrowserState>) -> Result<BrowserStats, String> {
    let tabs = state.tabs.lock();
    Ok(BrowserStats {
        total_tabs: tabs.len(),
        live_webviews: live_webview_count(&tabs),
        discarded_tabs: tabs
            .values()
            .filter(|record| record.snapshot.discarded)
            .count(),
        max_live_webviews: MAX_LIVE_WEBVIEWS,
        max_tabs: MAX_TABS,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fake_record(index: u64) -> TabRecord {
        TabRecord {
            snapshot: TabSnapshot {
                id: index.to_string(),
                title: format!("Tab {index}"),
                url: Some(format!("https://example.com/{index}")),
                loading: false,
                blocked: 0,
                has_webview: true,
                discarded: false,
            },
            webview_label: Some(format!("tab-{index}")),
            last_active: index,
        }
    }

    #[test]
    fn scheduler_keeps_320_tabs_with_bounded_live_webviews() {
        let mut tabs = HashMap::new();
        for index in 0..320u64 {
            tabs.insert(index.to_string(), fake_record(index));
        }

        let active = "319";
        while live_webview_count(&tabs) > MAX_LIVE_WEBVIEWS {
            let candidate = select_discard_candidate(&tabs, Some(active), active)
                .expect("candidate should exist while over budget");
            let record = tabs.get_mut(&candidate).expect("candidate must exist");
            record.webview_label = None;
            record.snapshot.has_webview = false;
            record.snapshot.discarded = true;
        }

        assert_eq!(tabs.len(), 320);
        assert_eq!(live_webview_count(&tabs), MAX_LIVE_WEBVIEWS);
        assert!(tabs.get(active).unwrap().webview_label.is_some());
        assert_eq!(
            tabs.values().filter(|record| record.snapshot.discarded).count(),
            320 - MAX_LIVE_WEBVIEWS
        );
    }

    #[test]
    fn tracker_parameters_are_removed_without_damaging_regular_query_data() {
        let url = validate_url(
            "https://example.com/page?utm_source=test&id=42&fbclid=x&srsltid=y",
        )
        .expect("valid URL");
        assert_eq!(url.as_str(), "https://example.com/page?id=42");
    }

    #[test]
    fn transient_internal_urls_do_not_replace_restorable_page_url() {
        assert!(persistable_page_url("about:blank").is_none());
        assert!(persistable_page_url("blob:https://example.com/1234").is_none());
        assert_eq!(
            persistable_page_url("https://example.com/page").as_deref(),
            Some("https://example.com/page")
        );
    }
}
