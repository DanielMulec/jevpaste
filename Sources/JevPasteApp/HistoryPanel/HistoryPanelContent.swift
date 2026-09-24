import Foundation
import SmartPasteCore

/// What the history panel displays: the pinned Active Item on top and the matching history rows below. Display
/// only — choosing a row always acts on the untouched `ClipboardItem`, never on its row text.
struct HistoryPanelContent: Equatable {
    private static let previewLineCount = 3

    let activeItem: ActiveItemPreview
    let rows: [HistoryRow]
    /// Shown in place of the rows when there are none.
    let emptyMessage: String

    /// - Parameter matches: the history items that match `query`, newest first (see `items(in:matching:)`).
    init(matches: [ClipboardItem], activeItem: ClipboardItem?, query: String) {
        self.activeItem = Self.preview(of: activeItem)
        rows = matches.map { item in
            HistoryRow(
                title: item.firstLine,
                detail: item.lineCount > 1 ? "\(item.lineCount) lines" : nil,
                isActive: activeItem.map(item.isSameHistoryEntry) ?? false
            )
        }
        emptyMessage = query.isBlank ? "No History Yet" : "No Matches"
    }

    /// The items whose text contains `query` anywhere, ignoring case and diacritics; all of them for a blank query.
    static func items(in history: [ClipboardItem], matching query: String) -> [ClipboardItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return history }
        return history.filter { $0.text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    private static func preview(of item: ClipboardItem?) -> ActiveItemPreview {
        guard let item else { return .nothing }
        guard !item.isConcealed else { return .concealed }
        let lines = item.nonBlankLines
        return .text(
            lines: Array(lines.prefix(previewLineCount)), moreLineCount: max(lines.count - previewLineCount, 0)
        )
    }
}

/// The pinned block at the top of the panel: what the next ⌘⇧V pastes from.
enum ActiveItemPreview: Equatable {
    /// Nothing copied since launch and nothing selected.
    case nothing
    /// A concealed copy (password manager): Active, but its text is never shown.
    case concealed
    /// The first non-blank lines (at most three) and how many further non-blank lines the item has.
    case text(lines: [String], moreLineCount: Int)
}

/// One history entry as a single row.
struct HistoryRow: Equatable {
    /// The first non-blank line, trimmed.
    let title: String
    /// "N lines" for a multi-line item, `nil` for a single line.
    let detail: String?
    /// This row is the Active Item.
    let isActive: Bool
}

extension ClipboardItem {
    /// The first non-blank line, trimmed — how the panel, and the "Active: …" note, name an item.
    var firstLine: String {
        nonBlankLines.first ?? ""
    }

    /// Clipboard History's identity rule: the same entry when the text is byte-identical after trimming.
    func isSameHistoryEntry(as other: ClipboardItem) -> Bool {
        Array(trimmedText.utf8) == Array(other.trimmedText.utf8)
    }

    fileprivate var lineCount: Int {
        trimmedText.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
    }

    fileprivate var nonBlankLines: [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    fileprivate var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
