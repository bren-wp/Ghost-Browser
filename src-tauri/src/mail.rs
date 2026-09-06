use crate::{
    profile::{MailAccount, ProfileStore},
    vault::{delete_secret, mail_secret_target, read_secret, store_secret},
};
use lettre::{
    Message, SmtpTransport, Transport,
    message::header::ContentType,
    transport::smtp::authentication::Credentials,
};
use native_tls::TlsConnector;
use serde::Serialize;
use std::time::Duration;
use tauri::State;
use uuid::Uuid;

const MAX_MAIL_LIST: usize = 100;
const MAX_SUBJECT: usize = 998;
const MAX_BODY_BYTES: usize = 1_048_576;
const NETWORK_TIMEOUT: Duration = Duration::from_secs(20);

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MailSummary {
    pub uid: u32,
    pub subject: String,
    pub from: String,
    pub date: String,
    pub seen: bool,
}

fn clean_host(input: &str, field: &str) -> Result<String, String> {
    let host = input.trim().to_ascii_lowercase();
    if host.is_empty()
        || host.len() > 253
        || host.chars().any(char::is_whitespace)
        || host.contains('/')
        || host.contains('@')
        || host.starts_with('.')
        || host.ends_with('.')
    {
        return Err(format!("{field} nije valjan"));
    }
    Ok(host)
}

fn validate_account_transport(
    imap_host: &str,
    imap_port: u16,
    smtp_host: &str,
    smtp_port: u16,
) -> Result<(String, String), String> {
    let imap_host = clean_host(imap_host, "IMAP poslužitelj")?;
    let smtp_host = clean_host(smtp_host, "SMTP poslužitelj")?;
    if imap_port == 0 || smtp_port == 0 {
        return Err("Port nije valjan".into());
    }
    if imap_port != 993 {
        return Err("Ghost Mail podržava samo IMAP preko izravnog TLS-a na portu 993".into());
    }
    if smtp_port != 465 && smtp_port != 587 {
        return Err("Ghost Mail podržava SMTP TLS na portu 465 ili obavezni STARTTLS na portu 587".into());
    }
    Ok((imap_host, smtp_host))
}

fn validate_password(password: &str) -> Result<(), String> {
    if password.is_empty() || password.len() > 2_048 || password.chars().any(|c| c == '\0') {
        return Err("Mail lozinka nije valjana".into());
    }
    Ok(())
}

fn bytes_text(value: Option<&[u8]>) -> String {
    value
        .map(|bytes| String::from_utf8_lossy(bytes).trim().to_string())
        .unwrap_or_default()
}

fn address_text(envelope: &imap::types::Envelope<'_>) -> String {
    let Some(address) = envelope.from.as_ref().and_then(|items| items.first()) else {
        return String::new();
    };

    let name = bytes_text(address.name.as_deref());
    let mailbox = bytes_text(address.mailbox.as_deref());
    let host = bytes_text(address.host.as_deref());
    let email = if !mailbox.is_empty() && !host.is_empty() {
        format!("{mailbox}@{host}")
    } else {
        mailbox
    };

    if !name.is_empty() && !email.is_empty() {
        format!("{name} <{email}>")
    } else if !email.is_empty() {
        email
    } else {
        name
    }
}

fn smtp_transport(account: &MailAccount, password: &str) -> Result<SmtpTransport, String> {
    let builder = if account.smtp_port == 465 {
        SmtpTransport::relay(&account.smtp_host)
    } else {
        SmtpTransport::starttls_relay(&account.smtp_host)
    }
    .map_err(|_| "SMTP TLS konfiguracija nije valjana".to_string())?;

    Ok(builder
        .port(account.smtp_port)
        .credentials(Credentials::new(account.email.clone(), password.to_string()))
        .timeout(Some(NETWORK_TIMEOUT))
        .build())
}

fn test_imap(account: &MailAccount, password: &str) -> Result<(), String> {
    let tls = TlsConnector::builder()
        .build()
        .map_err(|_| "TLS inicijalizacija nije uspjela".to_string())?;
    let client = imap::connect(
        (account.imap_host.as_str(), account.imap_port),
        account.imap_host.as_str(),
        &tls,
    )
    .map_err(|_| "Nije moguće uspostaviti sigurnu IMAP vezu".to_string())?;

    let mut session = client
        .login(&account.email, password)
        .map_err(|(error, _client)| format!("IMAP prijava nije uspjela: {error}"))?;
    session
        .examine("INBOX")
        .map_err(|error| format!("INBOX nije moguće otvoriti: {error}"))?;
    let _ = session.logout();
    Ok(())
}

fn test_smtp(account: &MailAccount, password: &str) -> Result<(), String> {
    let transport = smtp_transport(account, password)?;
    match transport.test_connection() {
        Ok(true) => Ok(()),
        Ok(false) => Err("SMTP poslužitelj nije potvrdio vezu".into()),
        Err(error) => Err(format!("SMTP TLS veza nije uspjela: {error}")),
    }
}

fn fetch_inbox_blocking(
    account: MailAccount,
    password: String,
    limit: usize,
) -> Result<Vec<MailSummary>, String> {
    let tls = TlsConnector::builder()
        .build()
        .map_err(|_| "TLS inicijalizacija nije uspjela".to_string())?;
    let client = imap::connect(
        (account.imap_host.as_str(), account.imap_port),
        account.imap_host.as_str(),
        &tls,
    )
    .map_err(|_| "Nije moguće uspostaviti sigurnu IMAP vezu".to_string())?;

    let mut session = client
        .login(&account.email, &password)
        .map_err(|(error, _client)| format!("IMAP prijava nije uspjela: {error}"))?;
    let mailbox = session
        .examine("INBOX")
        .map_err(|error| format!("INBOX nije moguće otvoriti: {error}"))?;

    if mailbox.exists == 0 {
        let _ = session.logout();
        return Ok(Vec::new());
    }

    let count = limit.clamp(1, MAX_MAIL_LIST) as u32;
    let start = mailbox.exists.saturating_sub(count).saturating_add(1).max(1);
    let range = format!("{start}:{}", mailbox.exists);
    let fetches = session
        .fetch(range, "(UID FLAGS ENVELOPE)")
        .map_err(|error| format!("Poruke nije moguće dohvatiti: {error}"))?;

    let mut summaries = Vec::with_capacity(fetches.len());
    for fetch in fetches.iter().rev() {
        let Some(uid) = fetch.uid else {
            continue;
        };
        let Some(envelope) = fetch.envelope() else {
            continue;
        };
        let seen = fetch
            .flags()
            .iter()
            .any(|flag| matches!(flag, imap::types::Flag::Seen));
        summaries.push(MailSummary {
            uid,
            subject: bytes_text(envelope.subject.as_deref()),
            from: address_text(envelope),
            date: bytes_text(envelope.date.as_deref()),
            seen,
        });
    }

    let _ = session.logout();
    Ok(summaries)
}

fn send_mail_blocking(
    account: MailAccount,
    password: String,
    to: String,
    subject: String,
    body: String,
) -> Result<(), String> {
    let to = to.trim();
    let subject = subject.trim();
    if to.is_empty() || subject.is_empty() {
        return Err("Primatelj i predmet su obavezni".into());
    }
    if subject.len() > MAX_SUBJECT || subject.chars().any(char::is_control) {
        return Err("Predmet poruke nije valjan".into());
    }
    if body.as_bytes().len() > MAX_BODY_BYTES {
        return Err("Poruka je prevelika".into());
    }

    let from_mailbox = account
        .email
        .parse()
        .map_err(|_| "Adresa pošiljatelja nije valjana".to_string())?;
    let to_mailbox = to
        .parse()
        .map_err(|_| "Adresa primatelja nije valjana".to_string())?;
    let message = Message::builder()
        .from(from_mailbox)
        .to(to_mailbox)
        .subject(subject)
        .header(ContentType::TEXT_PLAIN)
        .body(body)
        .map_err(|_| "Poruku nije moguće pripremiti".to_string())?;

    smtp_transport(&account, &password)?
        .send(&message)
        .map_err(|error| format!("Slanje poruke nije uspjelo: {error}"))?;
    Ok(())
}

#[tauri::command]
pub async fn mail_list_accounts(
    store: State<'_, ProfileStore>,
) -> Result<Vec<MailAccount>, String> {
    Ok(store.list_mail_accounts())
}

#[tauri::command]
pub async fn mail_add_account(
    store: State<'_, ProfileStore>,
    email: String,
    display_name: String,
    password: String,
    imap_host: String,
    imap_port: u16,
    smtp_host: String,
    smtp_port: u16,
) -> Result<MailAccount, String> {
    validate_password(&password)?;
    let (imap_host, smtp_host) =
        validate_account_transport(&imap_host, imap_port, &smtp_host, smtp_port)?;

    let probe = MailAccount {
        id: Uuid::new_v4().to_string(),
        email: email.trim().to_string(),
        display_name: display_name.trim().to_string(),
        imap_host: imap_host.clone(),
        imap_port,
        smtp_host: smtp_host.clone(),
        smtp_port,
        created_at: 0,
        updated_at: 0,
    };

    let probe_for_test = probe.clone();
    let password_for_test = password.clone();
    tauri::async_runtime::spawn_blocking(move || {
        test_imap(&probe_for_test, &password_for_test)?;
        test_smtp(&probe_for_test, &password_for_test)
    })
    .await
    .map_err(|error| error.to_string())??;

    let account = store.add_mail_account(
        &email,
        &display_name,
        &imap_host,
        imap_port,
        &smtp_host,
        smtp_port,
    )?;
    if let Err(error) = store_secret(&mail_secret_target(&account.id), &account.email, &password) {
        let _ = store.remove_mail_account(&account.id);
        return Err(error);
    }
    Ok(account)
}

#[tauri::command]
pub async fn mail_delete_account(
    store: State<'_, ProfileStore>,
    id: String,
) -> Result<bool, String> {
    Uuid::parse_str(&id).map_err(|_| "ID mail računa nije valjan".to_string())?;
    if store.get_mail_account(&id).is_none() {
        return Ok(false);
    }
    delete_secret(&mail_secret_target(&id))?;
    store.remove_mail_account(&id)
}

#[tauri::command]
pub async fn mail_fetch_inbox(
    store: State<'_, ProfileStore>,
    id: String,
    limit: Option<usize>,
) -> Result<Vec<MailSummary>, String> {
    Uuid::parse_str(&id).map_err(|_| "ID mail računa nije valjan".to_string())?;
    let account = store.get_mail_account(&id).ok_or("Mail račun nije pronađen")?;
    let password = read_secret(&mail_secret_target(&id))?;
    tauri::async_runtime::spawn_blocking(move || {
        fetch_inbox_blocking(account, password, limit.unwrap_or(30))
    })
    .await
    .map_err(|error| error.to_string())?
}

#[tauri::command]
pub async fn mail_send(
    store: State<'_, ProfileStore>,
    id: String,
    to: String,
    subject: String,
    body: String,
) -> Result<(), String> {
    Uuid::parse_str(&id).map_err(|_| "ID mail računa nije valjan".to_string())?;
    let account = store.get_mail_account(&id).ok_or("Mail račun nije pronađen")?;
    let password = read_secret(&mail_secret_target(&id))?;
    tauri::async_runtime::spawn_blocking(move || {
        send_mail_blocking(account, password, to, subject, body)
    })
    .await
    .map_err(|error| error.to_string())?
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_encrypted_mail_ports_are_accepted() {
        assert!(validate_account_transport("imap.example.com", 993, "smtp.example.com", 465).is_ok());
        assert!(validate_account_transport("imap.example.com", 993, "smtp.example.com", 587).is_ok());
        assert!(validate_account_transport("imap.example.com", 143, "smtp.example.com", 587).is_err());
        assert!(validate_account_transport("imap.example.com", 993, "smtp.example.com", 25).is_err());
    }

    #[test]
    fn suspicious_mail_hosts_are_rejected() {
        assert!(clean_host("smtp.example.com/path", "SMTP").is_err());
        assert!(clean_host("user@smtp.example.com", "SMTP").is_err());
        assert!(clean_host("smtp.example.com", "SMTP").is_ok());
    }

    #[test]
    fn oversized_mail_password_is_rejected() {
        let secret = "x".repeat(2_049);
        assert!(validate_password(&secret).is_err());
    }
}
