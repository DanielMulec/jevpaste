import SmartPasteCore

/// Interim `HistoryRepository` for the tracer bullet: keeps nothing. Persistent Clipboard History arrives with the
/// capture and history slice.
struct DiscardingHistoryRepository: HistoryRepository {
    func record(_ item: ClipboardItem) {}
}
