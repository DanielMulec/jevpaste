/// The Clipboard History operations as SQL over one connection. Synchronous; its owner confines it to one
/// serial queue, which is why it may be `@unchecked Sendable`.
final class ClipboardItemTable: @unchecked Sendable {
    private let connection: SQLiteConnection
    /// How many distinct items are kept; at least one.
    private var retentionLimit: Int

    init(connection: SQLiteConnection, retentionLimit: Int) {
        self.connection = connection
        self.retentionLimit = retentionLimit
    }

    /// In one transaction: upserts the copy under `key` with the next copy sequence (so it moves to the top and
    /// keeps `text`), then evicts the oldest items beyond the retention limit. Returns the number evicted.
    func record(_ text: String, under key: DistinctKey) throws(HistoryStoreFailure) -> Int {
        try connection.inTransaction(operation: "record") { () throws(HistoryStoreFailure) in
            try upsert(text, under: key)
            return try evictBeyondRetentionLimit()
        }
    }

    /// Sets a new retention limit and evicts the oldest items beyond it at once. Returns the number evicted.
    func changeRetentionLimit(to limit: Int) throws(HistoryStoreFailure) -> Int {
        retentionLimit = limit
        return try evictBeyondRetentionLimit()
    }

    /// Removes the item stored under `key`, if any. Returns the number removed.
    func delete(under key: DistinctKey) throws(HistoryStoreFailure) -> Int {
        try connection.run("DELETE FROM clipboard_item WHERE distinct_key = ?1", .blob(key.bytes), operation: "delete")
    }

    /// Removes every item. Returns the number removed.
    func clearAll() throws(HistoryStoreFailure) -> Int {
        try connection.run("DELETE FROM clipboard_item", operation: "clearAll")
    }

    private func upsert(_ text: String, under key: DistinctKey) throws(HistoryStoreFailure) {
        try connection.run(
            """
            INSERT INTO clipboard_item (distinct_key, text, copy_sequence)
            VALUES (?1, ?2, (SELECT COALESCE(MAX(copy_sequence), 0) + 1 FROM clipboard_item))
            ON CONFLICT (distinct_key) DO UPDATE SET text = excluded.text, copy_sequence = excluded.copy_sequence
            """,
            .blob(key.bytes), .text(text),
            operation: "record")
    }

    /// Deletes every row at or below the copy sequence of the newest row outside the limit.
    private func evictBeyondRetentionLimit() throws(HistoryStoreFailure) -> Int {
        try connection.run(
            """
            DELETE FROM clipboard_item WHERE copy_sequence <= (
                SELECT copy_sequence FROM clipboard_item ORDER BY copy_sequence DESC LIMIT 1 OFFSET ?1
            )
            """,
            .integer(retentionLimit),
            operation: "evict")
    }

    /// Every stored text, newest copy first.
    func textsNewestFirst() throws(HistoryStoreFailure) -> [String] {
        try connection.texts("SELECT text FROM clipboard_item ORDER BY copy_sequence DESC", operation: "items")
    }
}
