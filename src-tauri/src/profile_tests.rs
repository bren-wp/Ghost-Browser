#![cfg(test)]

use crate::profile::ProfileStore;
use uuid::Uuid;

#[test]
fn local_profile_round_trip_persists_library_metadata() {
    let nonce = Uuid::new_v4().to_string();
    let bookmark_url = format!("https://example.com/bookmark/{nonce}");
    let history_url = format!("https://example.com/history/{nonce}");
    let download_url = format!("https://example.com/download/{nonce}");
    let vault_origin = format!("https://vault-{nonce}.example.com");
    let vault_user = format!("ghost-user-{nonce}");
    let mail = format!("ghost-{nonce}@example.com");

    let store = ProfileStore::new();
    let bookmark = store
        .add_bookmark("Ghost CI favorite", &bookmark_url)
        .expect("bookmark must persist");
    store
        .record_history("Ghost CI history", &history_url)
        .expect("history must persist");
    store
        .record_download(&download_url)
        .expect("download must persist");
    let vault = store
        .upsert_vault_metadata(None, &vault_origin, &vault_user, "Ghost CI vault")
        .expect("vault metadata must persist");
    let mail_account = store
        .add_mail_account(
            &mail,
            "Ghost CI mail",
            "imap.example.com",
            993,
            "smtp.example.com",
            465,
        )
        .expect("mail metadata must persist");

    drop(store);

    let restored = ProfileStore::new();
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

    restored
        .remove_bookmark(&bookmark.id)
        .expect("bookmark cleanup must succeed");
    restored
        .remove_vault_metadata(&vault.id)
        .expect("vault metadata cleanup must succeed");
    restored
        .remove_mail_account(&mail_account.id)
        .expect("mail metadata cleanup must succeed");
    restored.clear_history().expect("history cleanup must succeed");
    restored.clear_downloads().expect("download cleanup must succeed");
}
