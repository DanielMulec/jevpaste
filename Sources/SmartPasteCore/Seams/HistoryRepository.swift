import Foundation

/// Persists Clipboard History across restarts and applies its retention policy.
///
/// Two Clipboard Items are the same history entry when their text is identical after trimming leading and
/// trailing whitespace; that trimmed text is the item's identity. The real adapter lives in `HistoryStore`
/// (SQLite); tests supply an in-memory fake.
public protocol HistoryRepository: Sendable {
    /// Stores a newly copied Clipboard Item and returns at once. Concealed, empty and whitespace-only items are
    /// refused. Re-copying an item already in history keeps the new copy's exact text and moves it to the top.
    /// Items beyond the retention limit are evicted, oldest first. `copiedAt` is kept with it (the latest copy's).
    func record(_ item: ClipboardItem, copiedAt: Date)

    /// Clipboard History, newest first. May block the caller briefly; sees every earlier `record`.
    func entries() -> [HistoryEntry]

    /// Removes the history entry with `item`'s identity; does nothing if there is none.
    func delete(_ item: ClipboardItem)

    /// Removes every history entry.
    func clearAll()

    /// Changes how many distinct items are kept (at least one). A lower limit evicts the oldest at once.
    func changeRetentionLimit(to limit: Int)
}
