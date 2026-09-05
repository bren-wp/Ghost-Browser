use crate::browser::BrowserState;
use tauri::{AppHandle, Emitter, Manager, Webview};
use webview2_com::{
    Microsoft::Web::WebView2::Win32::{
        COREWEBVIEW2_PERMISSION_STATE_DENY, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL,
        ICoreWebView2_2,
    },
    CoTaskMemPWSTR, PermissionRequestedEventHandler, WebResourceRequestedEventHandler, take_pwstr,
};
use windows::{Win32::System::Com::IStream, core::{Interface, PWSTR}};

pub fn install(webview: &Webview, tab_id: String, app: AppHandle) -> Result<(), String> {
    webview.with_webview(move |platform| unsafe {
        let controller = platform.controller();
        let core = match controller.CoreWebView2() { Ok(core) => core, Err(_) => return };
        let core2: ICoreWebView2_2 = match core.cast() { Ok(value) => value, Err(_) => return };
        let environment = match core2.Environment() { Ok(value) => value, Err(_) => return };

        let filter = CoTaskMemPWSTR::from("*");
        if core.AddWebResourceRequestedFilter(*filter.as_ref().as_pcwstr(), COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL).is_err() {
            return;
        }

        let app_for_filter = app.clone();
        let tab_for_filter = tab_id.clone();
        let environment_for_filter = environment.clone();
        let handler = WebResourceRequestedEventHandler::create(Box::new(move |sender, args| {
            let (Some(sender), Some(args)) = (sender, args) else { return Ok(()); };
            let request = args.Request()?;
            let mut uri = PWSTR::null();
            request.Uri(&mut uri)?;
            let request_url = take_pwstr(uri);

            let mut source = PWSTR::null();
            sender.Source(&mut source)?;
            let source_url = take_pwstr(source);

            let should_block = app_for_filter
                .try_state::<BrowserState>()
                .map(|state| state.privacy.should_block(&request_url, &source_url, "other"))
                .unwrap_or(false);

            if should_block {
                let reason = CoTaskMemPWSTR::from("Blocked by Ghost Browser");
                let headers = CoTaskMemPWSTR::from("Cache-Control: no-store\r\nContent-Type: text/plain; charset=utf-8");
                let response = environment_for_filter.CreateWebResourceResponse(
                    None::<&IStream>,
                    403,
                    *reason.as_ref().as_pcwstr(),
                    *headers.as_ref().as_pcwstr(),
                )?;
                args.SetResponse(&response)?;

                if let Some(state) = app_for_filter.try_state::<BrowserState>() {
                    if let Some(blocked) = state.increment_blocked(&tab_for_filter) {
                        let _ = app_for_filter.emit_to("main", "ghost://tab-event", serde_json::json!({
                            "id": tab_for_filter,
                            "blocked": blocked
                        }));
                    }
                }
            }
            Ok(())
        }));
        let mut token = 0_i64;
        let _ = core.add_WebResourceRequested(&handler, &mut token);

        let permission = PermissionRequestedEventHandler::create(Box::new(move |_sender, args| {
            if let Some(args) = args {
                args.SetState(COREWEBVIEW2_PERMISSION_STATE_DENY)?;
            }
            Ok(())
        }));
        let mut permission_token = 0_i64;
        let _ = core.add_PermissionRequested(&permission, &mut permission_token);

        if let Ok(settings) = core.Settings() {
            let _ = settings.SetAreDevToolsEnabled(cfg!(debug_assertions));
            let _ = settings.SetAreDefaultContextMenusEnabled(true);
            let _ = settings.SetIsStatusBarEnabled(false);
            let _ = settings.SetIsZoomControlEnabled(true);
        }
    }).map_err(|e| e.to_string())
}

pub fn go_back(webview: &Webview) -> Result<(), String> {
    webview.with_webview(|platform| unsafe {
        if let Ok(core) = platform.controller().CoreWebView2() { let _ = core.GoBack(); }
    }).map_err(|e| e.to_string())
}

pub fn go_forward(webview: &Webview) -> Result<(), String> {
    webview.with_webview(|platform| unsafe {
        if let Ok(core) = platform.controller().CoreWebView2() { let _ = core.GoForward(); }
    }).map_err(|e| e.to_string())
}
