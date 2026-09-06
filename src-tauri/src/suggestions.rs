use crate::profile::{Bookmark, HistoryEntry, ProfileStore};
use serde::Serialize;
use std::collections::HashSet;
use tauri::State;

const MAX_SUGGESTIONS: usize = 8;
const MAX_INPUT: usize = 512;

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct OmniboxSuggestion {
    pub title: String,
    pub url: String,
    pub kind: String,
}

fn score_match(title: &str, url: &str, needle: &str) -> Option<u8> {
    let title = title.to_ascii_lowercase();
    let url = url.to_ascii_lowercase();
    let needle = needle.to_ascii_lowercase();

    if title.starts_with(&needle) {
        Some(0)
    } else if url.starts_with(&needle) || url.starts_with(&format!("https://{needle}")) {
        Some(1)
    } else if title.contains(&needle) {
        Some(2)
    } else if url.contains(&needle) {
        Some(3)
    } else {
        None
    }
}

fn build_suggestions(
    bookmarks: &[Bookmark],
    history: &[HistoryEntry],
    input: &str,
) -> Vec<OmniboxSuggestion> {
    let needle = input.trim();
    if needle.is_empty() || needle.len() > MAX_INPUT || needle.chars().any(char::is_control) {
        return Vec::new();
    }

    let mut candidates: Vec<(u8, u64, OmniboxSuggestion)> = Vec::new();

    for item in bookmarks {
        if let Some(score) = score_match(&item.title, &item.url, needle) {
            candidates.push((
                score,
                u64::MAX.saturating_sub(item.created_at),
                OmniboxSuggestion {
                    title: item.title.clone(),
                    url: item.url.clone(),
                    kind: "bookmark".into(),
                },
            ));
        }
    }

    for item in history {
        if let Some(score) = score_match(&item.title, &item.url, needle) {
            candidates.push((
                score,
                u64::MAX.saturating_sub(item.visited_at),
                OmniboxSuggestion {
                    title: item.title.clone(),
                    url: item.url.clone(),
                    kind: "history".into(),
                },
            ));
        }
    }

    candidates.sort_by_key(|(score, recency, _)| (*score, *recency));

    let mut seen = HashSet::new();
    candidates
        .into_iter()
        .filter_map(|(_, _, item)| seen.insert(item.url.clone()).then_some(item))
        .take(MAX_SUGGESTIONS)
        .collect()
}

#[tauri::command]
pub async fn omnibox_suggestions(
    store: State<'_, ProfileStore>,
    input: String,
) -> Result<Vec<OmniboxSuggestion>, String> {
    let bookmarks = store.list_bookmarks();
    let history = store.list_history(1_000);
    Ok(build_suggestions(&bookmarks, &history, &input))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bookmark(title: &str, url: &str, created_at: u64) -> Bookmark {
        Bookmark {
            id: format!("b-{created_at}"),
            title: title.into(),
            url: url.into(),
            created_at,
        }
    }

    fn history(title: &str, url: &str, visited_at: u64) -> HistoryEntry {
        HistoryEntry {
            id: format!("h-{visited_at}"),
            title: title.into(),
            url: url.into(),
            visited_at,
        }
    }

    #[test]
    fn prefix_matches_rank_before_contains_matches() {
        let bookmarks = vec![bookmark("Ghosium Browser", "https://ghosium.example/", 1)];
        let history = vec![history(
            "News about Ghosium",
            "https://news.example/ghosium",
            2,
        )];
        let items = build_suggestions(&bookmarks, &history, "ghosium");
        assert_eq!(
            items.first().map(|item| item.url.as_str()),
            Some("https://ghosium.example/")
        );
    }

    #[test]
    fn duplicate_urls_are_returned_once() {
        let bookmarks = vec![bookmark("Example", "https://example.com/", 1)];
        let history = vec![history("Example", "https://example.com/", 2)];
        let items = build_suggestions(&bookmarks, &history, "example");
        assert_eq!(items.len(), 1);
    }

    #[test]
    fn suggestions_are_bounded_and_control_input_is_rejected() {
        let history: Vec<_> = (0..20)
            .map(|index| history("Example", &format!("https://example.com/{index}"), index))
            .collect();
        assert_eq!(
            build_suggestions(&[], &history, "example").len(),
            MAX_SUGGESTIONS
        );
        assert!(build_suggestions(&[], &history, "bad\nquery").is_empty());
    }
}
