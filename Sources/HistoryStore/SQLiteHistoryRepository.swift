import SmartPasteCore

/// The `HistoryRepository` adapter that will persist Clipboard History in SQLite.
///
/// Scaffold only: no storage yet.
public struct SQLiteHistoryRepository: HistoryRepository {
    public init() {}

    public func record(_ item: ClipboardItem) {}
}
