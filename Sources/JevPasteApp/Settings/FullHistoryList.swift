import Foundation
import SmartPasteCore
import os

/// Settings › Full History's logic: the whole Clipboard History, newest first, as two-line rows with the "Active"
/// tag; deleting one item and clearing all of it. It follows the Active Item and every copy while it exists. The
/// Active Item stays Active when its entry is deleted or cleared.
@MainActor
final class FullHistoryList {
    private static let log = Logger(subsystem: "jevpaste", category: "Settings")

    private let history: any HistoryRepository
    private let capture: CopyCapture
    private let now: () -> Date
    private var entries: [HistoryEntry] = []
    private(set) var rows: [HistoryEntryRow] = []
    /// Called after the rows changed because of a copy or a selection.
    var onChange: (@MainActor () -> Void)?

    init(
        history: any HistoryRepository, capture: CopyCapture, changes: ActiveItemChanges,
        now: @escaping () -> Date = Date.init
    ) {
        self.history = history
        self.capture = capture
        self.now = now
        changes.observe { [weak self] _ in
            self?.reload()
            self?.onChange?()
        }
    }

    /// "N Clipboard Items" under the list.
    var countText: String {
        entries.count == 1 ? "1 Clipboard Item" : "\(entries.count) Clipboard Items"
    }

    func reload() {
        entries = history.entries()
        let activeItem = capture.activeItem
        let time = now()
        rows = entries.map { HistoryEntryRow($0, activeItem: activeItem, now: time) }
    }

    func delete(row: Int) {
        guard entries.indices.contains(row) else { return }
        history.delete(entries[row].item)
        Self.log.notice("full history deleted one item")
        reload()
    }

    func clearAll() {
        history.clearAll()
        Self.log.notice("full history cleared \(self.entries.count, privacy: .public) items")
        reload()
    }
}
