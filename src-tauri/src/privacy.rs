use adblock::{
    Engine,
    lists::{FilterSet, ParseOptions},
    request::Request,
};
use parking_lot::Mutex;
use std::sync::Arc;

const DEFAULT_FILTERS: &str = include_str!("../resources/ghost-default-filters.txt");

#[derive(Clone)]
pub struct PrivacyEngine {
    engine: Arc<Mutex<Engine>>,
}

impl PrivacyEngine {
    pub fn new() -> Self {
        let mut set = FilterSet::new(false);
        set.add_filter_list(DEFAULT_FILTERS.to_owned(), ParseOptions::default());
        Self {
            engine: Arc::new(Mutex::new(Engine::new_with_filter_set(set))),
        }
    }

    pub fn should_block(&self, url: &str, source_url: &str, resource_type: &str) -> bool {
        let Ok(request) = Request::new(url, source_url, resource_type, "GET") else {
            return false;
        };
        self.engine
            .lock()
            .check_network_request(&request)
            .should_block()
    }
}

pub const DOCUMENT_START_SCRIPT: &str = r#"
(() => {
  'use strict';

  const deny = () => Promise.reject(
    new DOMException('Blocked by Ghost Browser privacy policy', 'NotAllowedError')
  );

  try {
    Object.defineProperty(Navigator.prototype, 'doNotTrack', {
      get: () => '1',
      configurable: false
    });
  } catch (_) {}

  try {
    Object.defineProperty(Navigator.prototype, 'globalPrivacyControl', {
      get: () => true,
      configurable: false
    });
  } catch (_) {}

  try {
    if ('bluetooth' in navigator && navigator.bluetooth) {
      Object.defineProperty(navigator.bluetooth, 'requestDevice', { value: deny, configurable: false });
    }
  } catch (_) {}

  try {
    if ('usb' in navigator && navigator.usb) {
      Object.defineProperty(navigator.usb, 'requestDevice', { value: deny, configurable: false });
    }
  } catch (_) {}

  try {
    if ('serial' in navigator && navigator.serial) {
      Object.defineProperty(navigator.serial, 'requestPort', { value: deny, configurable: false });
    }
  } catch (_) {}

  try {
    if ('hid' in navigator && navigator.hid) {
      Object.defineProperty(navigator.hid, 'requestDevice', { value: deny, configurable: false });
    }
  } catch (_) {}

  try {
    if ('Notification' in window && typeof Notification.requestPermission === 'function') {
      Object.defineProperty(Notification, 'requestPermission', { value: deny, configurable: false });
    }
  } catch (_) {}
})();
"#;
