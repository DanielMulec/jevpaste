import Foundation

/// What History Search lists for a query: the newest matching entries (at most `HistorySearch.rowLimit`), how many
/// entries matched in all, and how many Clipboard History holds.
public struct HistorySearchResults: Equatable, Sendable {
    public let matches: [HistoryEntry]
    public let matchCount: Int
    public let historyCount: Int
}

/// History Search: filters Clipboard History by a typed query. An entry matches when its whole text contains the
/// query — trimmed of surrounding whitespace and line breaks — ignoring case and diacritics.
public enum HistorySearch {
    /// How many matching Clipboard Items the menu lists under the search field.
    public static let rowLimit = 5

    /// The results for `query` over `history` (newest first), or `nil` for a blank query: no search, no rows.
    public static func results(for query: String, in history: [HistoryEntry]) -> HistorySearchResults? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        let matches = history.filter {
            $0.item.text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return HistorySearchResults(
            matches: Array(matches.prefix(rowLimit)), matchCount: matches.count, historyCount: history.count
        )
    }
}
