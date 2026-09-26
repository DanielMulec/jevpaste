import Foundation
import SmartPasteCore

extension ClipboardItem {
    /// The first non-blank line, trimmed — how History Search, Full History and the "Active: …" note name an item.
    var firstLine: String {
        text.split(whereSeparator: \.isNewline)
            .lazy.map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }

    /// Clipboard History's identity rule: the same entry when the text is byte-identical after trimming.
    func isSameHistoryEntry(as other: ClipboardItem) -> Bool {
        Array(trimmedText.utf8) == Array(other.trimmedText.utf8)
    }

    /// "4 lines" for a multi-line item, "18 chars" for a single line; counted on the trimmed text.
    var sizeDescription: String {
        let lineCount = trimmedText.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
        return lineCount > 1 ? "\(lineCount) lines" : "\(trimmedText.count) chars"
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension HistoryEntry {
    /// The dim second line of a row: "4 lines · 12 min ago"; without a copy time, only the size.
    func detail(now: Date) -> String {
        guard let copiedAt else { return item.sizeDescription }
        return item.sizeDescription + " · " + Self.age(of: copiedAt, now: now)
    }

    /// "just now", "12 min ago", "3 h ago", "2 d ago"; a copy time in the future (a clock change) is "just now".
    private static func age(of copiedAt: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(copiedAt) / 60)
        switch minutes {
        case ..<1: return "just now"
        case ..<60: return "\(minutes) min ago"
        case ..<(24 * 60): return "\(minutes / 60) h ago"
        default: return "\(minutes / (24 * 60)) d ago"
        }
    }
}
