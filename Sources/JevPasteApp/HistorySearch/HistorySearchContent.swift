import Foundation
import SmartPasteCore

/// What the History Search panel displays under its field: for a query, "N of M matches", up to five two-line rows
/// (or "No matching Clipboard Items"), then Full history… · Settings… · Quit; for a blank field only Settings… and
/// Quit. Display only — choosing a row acts on the untouched entry, never on its row text.
struct HistorySearchContent: Equatable {
    static let blankPlaceholder = "Search Clipboard History"

    /// The Active Item's first line, so the empty field says what ⌘⇧V pastes; never a concealed item's text.
    let placeholder: String
    /// "5 of 12 matches" while something matches; `nil` otherwise.
    let matchSummary: String?
    let rows: [HistoryEntryRow]
    /// The query matched nothing: "No matching Clipboard Items".
    let saysNothingMatches: Bool
    let menuItems: [HistorySearchMenuItem]

    init(query: String, history: [HistoryEntry], activeItem: ClipboardItem?, now: Date) {
        placeholder = Self.placeholder(for: activeItem)
        guard let results = HistorySearch.results(for: query, in: history) else {
            matchSummary = nil
            rows = []
            saysNothingMatches = false
            menuItems = [.settings, .quit]
            return
        }
        matchSummary = results.matchCount > 0 ? "\(results.matches.count) of \(results.matchCount) matches" : nil
        rows = results.matches.map { HistoryEntryRow($0, activeItem: activeItem, now: now) }
        saysNothingMatches = results.matchCount == 0
        menuItems = [.fullHistory(itemCount: results.historyCount), .settings, .quit]
    }

    private static func placeholder(for activeItem: ClipboardItem?) -> String {
        guard let activeItem, !activeItem.isConcealed, !activeItem.firstLine.isEmpty else { return blankPlaceholder }
        return activeItem.firstLine
    }
}

/// One Clipboard Item as two lines, in History Search and in Full History.
struct HistoryEntryRow: Equatable {
    /// The first non-blank line, trimmed.
    let title: String
    /// "4 lines · 12 min ago".
    let detail: String
    /// This row is the Active Item: an accent dot, or the "Active" tag.
    let isActive: Bool

    init(_ entry: HistoryEntry, activeItem: ClipboardItem?, now: Date) {
        title = entry.item.firstLine
        detail = entry.detail(now: now)
        isActive = activeItem.map(entry.item.isSameHistoryEntry) ?? false
    }
}

/// The menu-item block under the rows.
enum HistorySearchMenuItem: Equatable {
    /// "Full history… (M)", M = every Clipboard Item.
    case fullHistory(itemCount: Int)
    case settings
    case quit
}
