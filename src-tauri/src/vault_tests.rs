#![cfg(all(test, windows))]

use crate::vault::{delete_secret, read_secret, store_secret};
use uuid::Uuid;

#[test]
fn windows_credential_manager_round_trip() {
    let target = format!("GhostBrowser/Test/{}", Uuid::new_v4());
    let username = "ghost-ci-user";
    let secret = format!("ghost-ci-secret-{}", Uuid::new_v4());

    let result = (|| {
        store_secret(&target, username, &secret)?;
        let restored = read_secret(&target)?;
        if restored != secret {
            return Err("Windows Credential Manager returned a different secret".to_string());
        }
        Ok::<(), String>(())
    })();

    let cleanup = delete_secret(&target);
    result.expect("credential round trip must succeed");
    cleanup.expect("credential test entry must be removed");
    assert!(read_secret(&target).is_err(), "deleted credential must not remain readable");
}
