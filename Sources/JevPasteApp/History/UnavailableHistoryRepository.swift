import SmartPasteCore

/// The `HistoryRepository` used when the history file could not be opened at launch: it keeps nothing, so
/// Clipboard History stays empty while Smart Paste keeps working on the Active Item. The launch notice says why.
struct UnavailableHistoryRepository: HistoryRepository {
    func record(_ item: ClipboardItem) {}

    func items() -> [ClipboardItem] { [] }

    func delete(_ item: ClipboardItem) {}

    func clearAll() {}

    func changeRetentionLimit(to limit: Int) {}
}
