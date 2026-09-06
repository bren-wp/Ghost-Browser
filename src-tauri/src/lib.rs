mod browser;
mod mail;
mod privacy;
mod profile;
#[cfg(test)]
mod profile_tests;
mod search;
mod suggestions;
mod vault;
#[cfg(all(test, windows))]
mod vault_tests;
#[cfg(windows)]
mod webview2_guard;

use browser::BrowserState;
use profile::ProfileStore;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(BrowserState::new())
        .manage(ProfileStore::new())
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
            profile::list_bookmarks,
            profile::add_bookmark,
            profile::remove_bookmark,
            profile::record_history,
            profile::list_history,
            profile::clear_history,
            profile::record_download,
            profile::list_downloads,
            profile::clear_downloads,
            search::resolve_omnibox_input,
            search::resolve_search_query,
            suggestions::omnibox_suggestions,
            vault::vault_list,
            vault::vault_save,
            vault::vault_delete,
            vault::vault_fill,
            mail::mail_list_accounts,
            mail::mail_add_account,
            mail::mail_delete_account,
            mail::mail_fetch_inbox,
            mail::mail_send
        ])
        .run(tauri::generate_context!())
        .expect("Ghost Browser runtime failure");
}
