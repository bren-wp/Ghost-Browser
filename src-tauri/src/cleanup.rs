use crate::{browser, browser::BrowserState, profile::ProfileStore};
use tauri::{AppHandle, State};

/// Clears all data represented by the global "clear browsing data" action.
/// Favorites, Vault entries and Mail accounts are intentionally preserved.
#[tauri::command]
pub async fn clear_browsing_data(
    app: AppHandle,
    browser_state: State<'_, BrowserState>,
    profile: State<'_, ProfileStore>,
) -> Result<(), String> {
    browser::clear_browsing_data(app, browser_state).await?;
    profile.clear_history()?;
    profile.clear_downloads()?;
    Ok(())
}
