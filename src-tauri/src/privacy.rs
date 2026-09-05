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
        let Ok(request) = Request::new(url, source_url, resource_type) else {
            return false;
        };
        self.engine.lock().check_network_request(&request).matched
    }
}

pub const DOCUMENT_START_SCRIPT: &str = r#"
(() => {
  'use strict';
  const deny = () => Promise.reject(new DOMException('Blocked by Ghost Browser privacy policy', 'NotAllowedError'));
  try { Object.defineProperty(Navigator.prototype, 'doNotTrack', { get: () => '1', configurable: false }); } catch (_) {}
  try { Object.defineProperty(Navigator.prototype, 'globalPrivacyControl', { get: () => true, configurable: false }); } catch (_) {}
  try { Object.defineProperty(Navigator.prototype, 'hardwareConcurrency', { get: () => 4, configurable: false }); } catch (_) {}
  try { if ('deviceMemory' in Navigator.prototype) Object.defineProperty(Navigator.prototype, 'deviceMemory', { get: () => 8, configurable: false }); } catch (_) {}
  try {
    const BlockedRTC = class { constructor() { throw new DOMException('WebRTC disabled by Ghost Browser', 'NotAllowedError'); } };
    Object.defineProperty(window, 'RTCPeerConnection', { value: BlockedRTC, configurable: false });
    Object.defineProperty(window, 'webkitRTCPeerConnection', { value: BlockedRTC, configurable: false });
  } catch (_) {}
  try {
    if (navigator.mediaDevices) {
      Object.defineProperty(navigator.mediaDevices, 'getUserMedia', { value: deny, configurable: false });
      Object.defineProperty(navigator.mediaDevices, 'getDisplayMedia', { value: deny, configurable: false });
    }
  } catch (_) {}
})();
"#;
