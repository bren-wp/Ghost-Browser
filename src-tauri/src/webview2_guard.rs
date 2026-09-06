use crate::browser::BrowserState;
use tauri::{AppHandle, Emitter, Manager, Webview};
use webview2_com::{
    Microsoft::Web::WebView2::Win32::{
        COREWEBVIEW2_PERMISSION_KIND_CAMERA, COREWEBVIEW2_PERMISSION_KIND_GEOLOCATION,
        COREWEBVIEW2_PERMISSION_KIND_MICROPHONE, COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION,
        COREWEBVIEW2_PERMISSION_STATE_DEFAULT, COREWEBVIEW2_PERMISSION_STATE_DENY,
        COREWEBVIEW2_TRACKING_PREVENTION_LEVEL_STRICT, COREWEBVIEW2_WEB_RESOURCE_CONTEXT,
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT,
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FETCH, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FONT,
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_MEDIA,
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT_OTHER, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_PING,
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_STYLESHEET,
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT_WEBSOCKET,
        COREWEBVIEW2_WEB_RESOURCE_CONTEXT_XML_HTTP_REQUEST, ICoreWebView2_2, ICoreWebView2_13,
        ICoreWebView2PermissionRequestedEventArgs3, ICoreWebView2Profile3, ICoreWebView2Settings4,
    },
    CoTaskMemPWSTR, PermissionRequestedEventHandler, WebResourceRequestedEventHandler, take_pwstr,
};
use windows::{
    Win32::{Foundation::BOOL, System::Com::IStream},
    core::{Interface, PWSTR},
};

fn adblock_resource_type(context: COREWEBVIEW2_WEB_RESOURCE_CONTEXT) -> &'static str {
    if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT {
        "document"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_STYLESHEET {
        "stylesheet"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE {
        "image"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_MEDIA {
        "media"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FONT {
        "font"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT {
        "script"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_XML_HTTP_REQUEST {
        "xmlhttprequest"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FETCH {
        "fetch"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_WEBSOCKET {
        "websocket"
    } else if context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_PING {
        "ping"
    } else {
        "other"
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

            if let Ok(core13) = core.cast::<ICoreWebView2_13>() {
                if let Ok(profile) = core13.Profile() {
                    if let Ok(profile3) = profile.cast::<ICoreWebView2Profile3>() {
                        let _ = profile3.SetPreferredTrackingPreventionLevel(
                            COREWEBVIEW2_TRACKING_PREVENTION_LEVEL_STRICT,
                        );
                    }
                }
            }

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
                let mut uri = PWSTR::null();
                request.Uri(&mut uri)?;
                let request_url = take_pwstr(uri);

                let mut source = PWSTR::null();
                sender.Source(&mut source)?;
                let source_url = take_pwstr(source);

                let mut context = COREWEBVIEW2_WEB_RESOURCE_CONTEXT_OTHER;
                args.ResourceContext(&mut context)?;
                let resource_type = adblock_resource_type(context);

                let should_block = context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_PING
                    || app_for_filter
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
                    let mut kind = COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
                    let mut user_initiated = BOOL(0);
                    args.PermissionKind(&mut kind)?;
                    args.IsUserInitiated(&mut user_initiated)?;

                    if let Ok(args3) = args.cast::<ICoreWebView2PermissionRequestedEventArgs3>() {
                        let _ = args3.SetSavesInProfile(false);
                    }

                    let may_prompt = user_initiated.0 != 0
                        && (kind == COREWEBVIEW2_PERMISSION_KIND_CAMERA
                            || kind == COREWEBVIEW2_PERMISSION_KIND_MICROPHONE
                            || kind == COREWEBVIEW2_PERMISSION_KIND_GEOLOCATION);

                    args.SetState(if may_prompt {
                        COREWEBVIEW2_PERMISSION_STATE_DEFAULT
                    } else {
                        COREWEBVIEW2_PERMISSION_STATE_DENY
                    })?;
                }
                Ok(())
            }));
            let mut permission_token = 0_i64;
            let _ = core.add_PermissionRequested(&permission, &mut permission_token);

            if let Ok(settings) = core.Settings() {
                let _ = settings.SetAreDevToolsEnabled(false);
                let _ = settings.SetAreDefaultContextMenusEnabled(true);
                let _ = settings.SetAreHostObjectsAllowed(false);
                let _ = settings.SetIsWebMessageEnabled(false);
                let _ = settings.SetIsStatusBarEnabled(false);
                let _ = settings.SetIsZoomControlEnabled(true);
                let _ = settings.SetIsBuiltInErrorPageEnabled(true);

                if let Ok(settings4) = settings.cast::<ICoreWebView2Settings4>() {
                    let _ = settings4.SetIsGeneralAutofillEnabled(false);
                    let _ = settings4.SetIsPasswordAutosaveEnabled(false);
                }
            }
        })
        .map_err(|error| error.to_string())
}

pub fn go_back(webview: &Webview) -> Result<(), String> {
    webview
        .with_webview(|platform| unsafe {
            if let Ok(core) = platform.controller().CoreWebView2() {
                let _ = core.GoBack();
            }
        })
        .map_err(|error| error.to_string())
}

pub fn go_forward(webview: &Webview) -> Result<(), String> {
    webview
        .with_webview(|platform| unsafe {
            if let Ok(core) = platform.controller().CoreWebView2() {
                let _ = core.GoForward();
            }
        })
        .map_err(|error| error.to_string())
}
