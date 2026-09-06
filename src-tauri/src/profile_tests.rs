#![cfg(test)]

use crate::profile::ProfileStore;
use std::{env, fs};
use uuid::Uuid;

#[test]
fn local_profile_round_trip_persists_library_metadata() {
    let nonce = Uuid::new_v4().to_string();
    let sandbox = env::temp_dir().join(format!("ghosium-browser-profile-test-{nonce}"));
    fs::create_dir_all(&sandbox).expect("temporary profile root must be created");
    let profile_path = sandbox.join("profile.json");

    let bookmark_url = format!("https://example.com/bookmark/{nonce}");
    let history_url = format!("https://example.com/history/{nonce}");
    let download_url = format!("https://example.com/download/{nonce}");
    let vault_origin = format!("https://vault-{nonce}.example.com");
    let vault_user = format!("ghosium-user-{nonce}");
    let mail = format!("ghosium-{nonce}@example.com");

    let store = ProfileStore::new_for_test(profile_path.clone());
    let bookmark = store
        .add_bookmark("Ghosium CI favorite", &bookmark_url)
        .expect("bookmark must persist");
    store
        .record_history("Ghosium CI history", &history_url)
        .expect("history must persist");
    store
        .record_download(&download_url)
        .expect("download must persist");
    let vault = store
        .upsert_vault_metadata(None, &vault_origin, &vault_user, "Ghosium CI vault")
        .expect("vault metadata must persist");
    let mail_account = store
        .add_mail_account(
            &mail,
            "Ghosium CI mail",
            "imap.example.com",
            993,
            "smtp.example.com",
            465,
        )
        .expect("mail metadata must persist");

    drop(store);

    let restored = ProfileStore::new_for_test(profile_path);
    assert!(restored.list_bookmarks().iter().any(|item| item.id == bookmark.id));
    assert!(restored.list_history(10_000).iter().any(|item| item.url == history_url));
    assert!(restored.list_downloads(2_000).iter().any(|item| item.url == download_url));
    assert_eq!(
        restored.get_vault(&vault.id).as_ref().map(|item| item.username.as_str()),
        Some(vault_user.as_str())
    );
    assert_eq!(
        restored
            .get_mail_account(&mail_account.id)
            .as_ref()
            .map(|item| item.email.as_str()),
        Some(mail.as_str())
    );

    drop(restored);
    fs::remove_dir_all(&sandbox).expect("temporary profile sandbox must be removed");
}
