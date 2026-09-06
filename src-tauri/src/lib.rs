mod browser;
mod privacy;
mod search;
#[cfg(windows)]
mod webview2_guard;

use browser::BrowserState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(BrowserState::new())
        .invoke_handler(tauri::generate_handler![
            browser::create_tab,
            browser::set_active_tab,
            browser::set_overlay_open,
            browser::navigate_tab,
            browser::close_tab,
            browser::reload_tab,
            browser::go_back,
            browser::go_forward,
            browser::sync_viewport,
            browser::clear_browsing_data,
            browser::discard_inactive_tabs,
            browser::browser_stats,
            search::resolve_omnibox_input,
            search::resolve_search_query
        ])
        .run(tauri::generate_context!())
        .expect("Ghost Browser runtime failure");
}
