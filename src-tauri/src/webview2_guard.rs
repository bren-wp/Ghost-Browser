use crate::browser::BrowserState;
use tauri::{AppHandle, Emitter, Manager, Webview};
use webview2_com::{
    Microsoft::Web::WebView2::Win32::{
        COREWEBVIEW2_PERMISSION_STATE_DENY, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL,
        ICoreWebView2_2,
    },
    CoTaskMemPWSTR, PermissionRequestedEventHandler, WebResourceRequestedEventHandler, take_pwstr,
};
use windows::{
    Win32::System::Com::IStream,
    core::{HSTRING, Interface, PWSTR},
};

fn adblock_resource_type(context: i32) -> &'static str {
    match context {
        1 => "document",
        2 => "stylesheet",
        3 => "image",
        4 => "media",
        5 => "font",
        6 => "script",
        7 | 8 => "xmlhttprequest",
        10 | 14 => "ping",
        11 => "websocket",
        _ => "other",
    }
}

pub fn install(webview: &Webview, tab_id: String, app: AppHandle) -> Result<(), String> {
    webview
        .with_webview(move |platform| unsafe {
            let controller = platform.controller();
            let core = match controller.CoreWebView2() {
                Ok(core) => core,
                Err(_) => return,
            };
            let core2: ICoreWebView2_2 = match core.cast() {
                Ok(value) => value,
                Err(_) => return,
            };
            let environment = match core2.Environment() {
                Ok(value) => value,
                Err(_) => return,
            };

            let filter = CoTaskMemPWSTR::from("*");
            if core
                .AddWebResourceRequestedFilter(
                    *filter.as_ref().as_pcwstr(),
                    COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL,
                )
                .is_err()
            {
                return;
            }

            let app_for_filter = app.clone();
            let tab_for_filter = tab_id.clone();
            let environment_for_filter = environment.clone();
            let handler = WebResourceRequestedEventHandler::create(Box::new(move |sender, args| {
                let (Some(sender), Some(args)) = (sender, args) else {
                    return Ok(());
                };
                let request = args.Request()?;

                if let Ok(headers) = request.Headers() {
                    let _ = headers.SetHeader(&HSTRING::from("DNT"), &HSTRING::from("1"));
                    let _ = headers.SetHeader(&HSTRING::from("Sec-GPC"), &HSTRING::from("1"));
                }

                let mut uri = PWSTR::null();
                request.Uri(&mut uri)?;
                let request_url = take_pwstr(uri);

                let mut source = PWSTR::null();
                sender.Source(&mut source)?;
                let source_url = take_pwstr(source);

                let mut resource_context = COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL;
                let _ = args.ResourceContext(&mut resource_context);
                let resource_type = adblock_resource_type(resource_context.0);

                let should_block = app_for_filter
                    .try_state::<BrowserState>()
                    .map(|state| {
                        state
                            .privacy
                            .should_block(&request_url, &source_url, resource_type)
                    })
                    .unwrap_or(false);

                if should_block {
                    let reason = CoTaskMemPWSTR::from("Blocked by Ghost Browser");
                    let headers = CoTaskMemPWSTR::from(
                        "Cache-Control: no-store\r\nContent-Type: text/plain; charset=utf-8",
                    );
                    let response = environment_for_filter.CreateWebResourceResponse(
                        None::<&IStream>,
                        403,
                        *reason.as_ref().as_pcwstr(),
                        *headers.as_ref().as_pcwstr(),
                    )?;
                    args.SetResponse(&response)?;

                    if let Some(state) = app_for_filter.try_state::<BrowserState>() {
                        if let Some(blocked) = state.increment_blocked(&tab_for_filter) {
                            let _ = app_for_filter.emit_to(
                                "main",
                                "ghost://tab-event",
                                serde_json::json!({
                                    "id": tab_for_filter,
                                    "blocked": blocked
                                }),
                            );
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
        })
        .map_err(|e| e.to_string())
}

pub fn go_back(webview: &Webview) -> Result<(), String> {
    webview
        .with_webview(|platform| unsafe {
            if let Ok(core) = platform.controller().CoreWebView2() {
                let _ = core.GoBack();
            }
        })
        .map_err(|e| e.to_string())
}

pub fn go_forward(webview: &Webview) -> Result<(), String> {
    webview
        .with_webview(|platform| unsafe {
            if let Ok(core) = platform.controller().CoreWebView2() {
                let _ = core.GoForward();
            }
        })
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::adblock_resource_type;

    #[test]
    fn maps_webview2_contexts_to_adblock_types() {
        assert_eq!(adblock_resource_type(1), "document");
        assert_eq!(adblock_resource_type(2), "stylesheet");
        assert_eq!(adblock_resource_type(3), "image");
        assert_eq!(adblock_resource_type(5), "font");
        assert_eq!(adblock_resource_type(6), "script");
        assert_eq!(adblock_resource_type(7), "xmlhttprequest");
        assert_eq!(adblock_resource_type(8), "xmlhttprequest");
        assert_eq!(adblock_resource_type(11), "websocket");
        assert_eq!(adblock_resource_type(16), "other");
    }
}
