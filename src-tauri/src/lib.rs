mod browser;
mod privacy;
#[cfg(windows)]
mod webview2_guard;

use browser::BrowserState;
use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(BrowserState::new())
        .setup(|app| {
            let main = app
                .get_webview_window("main")
                .ok_or("main window was not created")?;
            #[cfg(debug_assertions)]
            main.open_devtools();
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            browser::create_tab,
            browser::set_active_tab,
            browser::navigate_tab,
            browser::close_tab,
            browser::reload_tab,
            browser::go_back,
            browser::go_forward,
            browser::sync_viewport,
            browser::clear_browsing_data
        ])
        .run(tauri::generate_context!())
        .expect("Ghost Browser runtime failure");
}
