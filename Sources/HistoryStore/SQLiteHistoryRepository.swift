import Foundation
import OSLog
import SmartPasteCore

/// The `HistoryRepository` adapter: Clipboard History in one SQLite file.
///
/// One serial queue owns the connection. Writes are enqueued and return at once on the caller's thread (the
/// main actor included); `items()` waits on the queue, so it sees every write enqueued before it.
/// Diagnostics carry operations, row counts, result codes and the file name, never item text.
public final class SQLiteHistoryRepository: HistoryRepository {
    public static let defaultRetentionLimit = 500

    private static let log = Logger(subsystem: "jevpaste", category: "HistoryStore")
    private let queue = DispatchQueue(label: "jevpaste.HistoryStore")
    private let table: ClipboardItemTable
    private let fileName: String
    private let onFailure: @Sendable (HistoryStoreFailure) -> Void

    /// Opens the history file, creating it and its directory if absent.
    /// - Parameter onFailure: Called on the repository's queue, once per operation that fails after a successful
    ///   open (a lost write, or a read that returned nothing), so the shell can show a visible indicator.
    /// - Throws: `HistoryStoreFailure` when the directory or file is unusable, the file is not a database, or its
    ///   schema is newer than this build. The caller shows the failure; nothing is retried here.
    public init(
        fileURL: URL = HistoryStoreLocation.defaultFileURL,
        retentionLimit: Int = defaultRetentionLimit,
        onFailure: @escaping @Sendable (HistoryStoreFailure) -> Void = { _ in }
    ) throws(HistoryStoreFailure) {
        fileName = fileURL.lastPathComponent
        self.onFailure = onFailure
        do {
            try HistoryStoreLocation.prepareFile(at: fileURL)
            let connection = try SQLiteConnection(fileURL: fileURL)
            try HistoryStoreLocation.restrictToUser(fileURL)
            try HistoryStoreSchema.prepare(connection)
            table = ClipboardItemTable(connection: connection, retentionLimit: Self.atLeastOne(retentionLimit))
        } catch {
            Self.logFailure(of: "open", on: fileURL.lastPathComponent, error)
            throw error
        }
    }

    public func record(_ item: ClipboardItem) {
        guard !item.isConcealed else {
            Self.log.info("record refused: concealed item")
            return
        }
        queue.async { [self] in
            guard let key = DistinctKey(of: item.text) else {
                Self.log.info("record refused: empty or whitespace-only item")
                return
            }
            let evicted = perform("record") { () throws(HistoryStoreFailure) in
                try table.record(item.text, under: key)
            }
            Self.logEviction(evicted)
        }
    }

    public func items() -> [ClipboardItem] {
        queue.sync {
            let texts = perform("items") { () throws(HistoryStoreFailure) in try table.textsNewestFirst() }
            return (texts ?? []).map { ClipboardItem(text: $0) }
        }
    }

    public func delete(_ item: ClipboardItem) {
        queue.async { [self] in
            guard let key = DistinctKey(of: item.text) else { return }
            let deleted = perform("delete") { () throws(HistoryStoreFailure) in try table.delete(under: key) }
            Self.log.info("deleted \(deleted ?? 0, privacy: .public) item")
        }
    }

    public func clearAll() {
        queue.async { [self] in
            let cleared = perform("clearAll") { () throws(HistoryStoreFailure) in try table.clearAll() }
            Self.log.info("cleared \(cleared ?? 0, privacy: .public) items")
        }
    }

    public func changeRetentionLimit(to limit: Int) {
        let limit = Self.atLeastOne(limit)
        queue.async { [self] in
            let evicted = perform("changeRetentionLimit") { () throws(HistoryStoreFailure) in
                try table.changeRetentionLimit(to: limit)
            }
            Self.logEviction(evicted)
        }
    }

    /// A retention limit below one would keep nothing, not even the item just copied; it is raised to one.
    private static func atLeastOne(_ limit: Int) -> Int {
        guard limit < 1 else { return limit }
        log.notice("retention limit \(limit, privacy: .public) raised to 1")
        return 1
    }

    private static func logEviction(_ evictedCount: Int?) {
        guard let evictedCount, evictedCount > 0 else { return }
        log.info("evicted \(evictedCount, privacy: .public) oldest items beyond the retention limit")
    }

    /// Runs one table operation on the queue; a failure is logged with its result code, reported through
    /// `onFailure`, and yields `nil`.
    private func perform<Result>(
        _ operation: String,
        _ body: () throws(HistoryStoreFailure) -> Result
    ) -> Result? {
        do {
            return try body()
        } catch {
            Self.logFailure(of: operation, on: fileName, error)
            onFailure(error)
            return nil
        }
    }

    private static func logFailure(of operation: String, on fileName: String, _ failure: HistoryStoreFailure) {
        let reason = String(describing: failure)
        log.error("\(operation, privacy: .public) on \(fileName, privacy: .public): \(reason, privacy: .public)")
    }
}
