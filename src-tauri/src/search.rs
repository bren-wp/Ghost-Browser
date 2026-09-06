use std::net::IpAddr;
use url::Url;

const MAX_INPUT_LENGTH: usize = 8192;
const MAX_QUERY_LENGTH: usize = 2048;
const PRIVATE_SEARCH_ENDPOINT: &str = "https://search.brave.com/search";

fn validate_input(input: &str) -> Result<&str, String> {
    let input = input.trim();
    if input.is_empty() {
        return Err("Upišite pojam za pretraživanje ili web-adresu".into());
    }
    if input.len() > MAX_INPUT_LENGTH {
        return Err("Unos je predugačak".into());
    }
    if input.chars().any(char::is_control) {
        return Err("Unos sadrži nedopuštene znakove".into());
    }
    Ok(input)
}

fn validate_query(query: &str) -> Result<&str, String> {
    let query = query.trim();
    if query.is_empty() {
        return Err("Upišite pojam za pretraživanje".into());
    }
    if query.len() > MAX_QUERY_LENGTH {
        return Err("Upit za pretraživanje je predugačak".into());
    }
    if query.chars().any(char::is_control) {
        return Err("Upit sadrži nedopuštene znakove".into());
    }
    Ok(query)
}

fn safe_http_url(url: &Url) -> bool {
    matches!(url.scheme(), "http" | "https")
        && url.host_str().is_some()
        && url.username().is_empty()
        && url.password().is_none()
        && url.as_str().len() <= MAX_INPUT_LENGTH
        && !url.as_str().chars().any(char::is_control)
}

fn parse_explicit_http(input: &str) -> Result<Option<String>, String> {
    if !input.to_ascii_lowercase().starts_with("http://")
        && !input.to_ascii_lowercase().starts_with("https://")
    {
        return Ok(None);
    }

    let url = Url::parse(input).map_err(|_| "Neispravna web-adresa".to_string())?;
    if !safe_http_url(&url) {
        return Err("Ghost Browser dopušta samo valjane HTTP i HTTPS adrese".into());
    }
    Ok(Some(url.to_string()))
}

fn looks_like_host(input: &str) -> bool {
    if input.chars().any(char::is_whitespace) {
        return false;
    }

    let Ok(probe) = Url::parse(&format!("http://{input}")) else {
        return false;
    };
    let Some(host) = probe.host_str() else {
        return false;
    };

    host.eq_ignore_ascii_case("localhost")
        || host.contains('.')
        || host.parse::<IpAddr>().is_ok()
        || (input.starts_with('[') && input.contains(']'))
}

fn build_direct_url(input: &str) -> Result<Option<String>, String> {
    if !looks_like_host(input) {
        return Ok(None);
    }

    let http_probe = Url::parse(&format!("http://{input}"))
        .map_err(|_| "Neispravna web-adresa".to_string())?;
    let host = http_probe
        .host_str()
        .ok_or_else(|| "Neispravna web-adresa".to_string())?;
    let is_local = host.eq_ignore_ascii_case("localhost") || host.parse::<IpAddr>().is_ok();
    let scheme = if is_local { "http" } else { "https" };
    let url = Url::parse(&format!("{scheme}://{input}"))
        .map_err(|_| "Neispravna web-adresa".to_string())?;

    if !safe_http_url(&url) {
        return Err("Ghost Browser dopušta samo valjane HTTP i HTTPS adrese".into());
    }
    Ok(Some(url.to_string()))
}

pub fn build_private_search_url(query: &str) -> Result<String, String> {
    let query = validate_query(query)?;
    let mut url = Url::parse(PRIVATE_SEARCH_ENDPOINT)
        .map_err(|_| "Interna konfiguracija pretraživanja nije valjana".to_string())?;
    url.query_pairs_mut().append_pair("q", query);
    Ok(url.to_string())
}

pub fn resolve_omnibox(input: &str) -> Result<String, String> {
    let input = validate_input(input)?;

    if let Some(url) = parse_explicit_http(input)? {
        return Ok(url);
    }
    if let Some(url) = build_direct_url(input)? {
        return Ok(url);
    }

    build_private_search_url(input)
}

#[tauri::command]
pub async fn resolve_omnibox_input(input: String) -> Result<String, String> {
    resolve_omnibox(&input)
}

#[tauri::command]
pub async fn resolve_search_query(query: String) -> Result<String, String> {
    build_private_search_url(&query)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plain_text_becomes_encoded_search_without_tracking_identifiers() {
        let url = resolve_omnibox("ghost browser privatnost")
            .expect("search URL should be generated");
        assert_eq!(
            url,
            "https://search.brave.com/search?q=ghost+browser+privatnost"
        );
    }

    #[test]
    fn domain_without_scheme_becomes_https_url() {
        assert_eq!(
            resolve_omnibox("example.com/path?q=42").unwrap(),
            "https://example.com/path?q=42"
        );
    }

    #[test]
    fn localhost_and_ip_default_to_http() {
        assert_eq!(
            resolve_omnibox("localhost:3000/test").unwrap(),
            "http://localhost:3000/test"
        );
        assert_eq!(
            resolve_omnibox("127.0.0.1:8080").unwrap(),
            "http://127.0.0.1:8080/"
        );
    }

    #[test]
    fn explicit_https_is_preserved() {
        assert_eq!(
            resolve_omnibox("https://example.com/a").unwrap(),
            "https://example.com/a"
        );
    }

    #[test]
    fn unsupported_scheme_is_not_executed_as_navigation() {
        let url = resolve_omnibox("javascript:alert(1)").unwrap();
        assert!(url.starts_with("https://search.brave.com/search?q="));
    }

    #[test]
    fn credentials_in_explicit_url_are_rejected() {
        assert!(resolve_omnibox("https://user:secret@example.com").is_err());
    }

    #[test]
    fn control_characters_are_rejected() {
        assert!(resolve_omnibox("hello\nworld").is_err());
    }
}
