use url::Url;

const MAX_QUERY_LENGTH: usize = 2048;
const PRIVATE_SEARCH_ENDPOINT: &str = "https://search.brave.com/search";

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

pub fn build_private_search_url(query: &str) -> Result<String, String> {
    let query = validate_query(query)?;
    let mut url = Url::parse(PRIVATE_SEARCH_ENDPOINT)
        .map_err(|_| "Interna konfiguracija pretraživanja nije valjana".to_string())?;
    url.query_pairs_mut().append_pair("q", query);
    Ok(url.to_string())
}

#[tauri::command]
pub async fn resolve_search_query(query: String) -> Result<String, String> {
    build_private_search_url(&query)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn query_is_encoded_without_tracking_identifiers() {
        let url = build_private_search_url("ghost browser privatnost")
            .expect("search URL should be generated");
        assert_eq!(
            url,
            "https://search.brave.com/search?q=ghost+browser+privatnost"
        );
    }

    #[test]
    fn control_characters_are_rejected() {
        assert!(build_private_search_url("hello\nworld").is_err());
    }
}
