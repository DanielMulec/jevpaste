/// Persists Clipboard History across restarts and applies the retention policy decided in Core.
///
/// The real adapter lives in `HistoryStore` (SQLite); tests supply an in-memory fake.
public protocol HistoryRepository: Sendable {}
