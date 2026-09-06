use crate::browser::BrowserState;
use tauri::{AppHandle, Emitter, Manager, Webview};
use webview2_com::{
    CoTaskMemPWSTR,
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
    PermissionRequestedEventHandler, WebResourceRequestedEventHandler, take_pwstr,
};
use windows::{
    Win32::System::Com::IStream,
  
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

                    }
                    Ok(())
                }));
            let mut token = 0_i64;
            let _ = core.add_WebResourceRequested(&handler, &mut token);

            let mut permission_token = 0_i64;
            let _ = core.add_PermissionRequested(&permission, &mut permission_token);

            if let Ok(settings) = core.Settings() {
                let _ = settings.SetAreDevToolsEnabled(cfg!(debug_assertions));
                let _ = settings.SetAreDefaultContextMenusEnabled(true);
                let _ = settings.SetIsStatusBarEnabled(false);
                let _ = settings.SetIsZoomControlEnabled(true);
            }

}

pub fn go_back(webview: &Webview) -> Result<(), String> {
    webview
        .with_webview(|platform| unsafe {
            if let Ok(core) = platform.controller().CoreWebView2() {
                let _ = core.GoBack();
            }
        })

}

pub fn go_forward(webview: &Webview) -> Result<(), String> {
    webview
        .with_webview(|platform| unsafe {
            if let Ok(core) = platform.controller().CoreWebView2() {
                let _ = core.GoForward();
            }
        })

}
