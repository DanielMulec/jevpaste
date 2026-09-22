import SmartPasteCore

/// Interim `HistoryRepository` for the tracer bullet: keeps nothing, so Clipboard History is always empty.
/// Replaced by `SQLiteHistoryRepository` in the capture and history slice.
struct DiscardingHistoryRepository: HistoryRepository {
    func record(_ item: ClipboardItem) {}

    func items() -> [ClipboardItem] { [] }

    func delete(_ item: ClipboardItem) {}

    func clearAll() {}

    func changeRetentionLimit(to limit: Int) {}
}
