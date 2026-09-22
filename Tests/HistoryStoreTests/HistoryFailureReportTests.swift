import Foundation
import HistoryStore
import SQLite3
import SmartPasteCore
import Testing

/// Collects the failures a repository reports from its queue.
final class ReportedFailures: @unchecked Sendable {
    private let lock = NSLock()
    private var failures: [HistoryStoreFailure] = []

    var all: [HistoryStoreFailure] {
        lock.withLock { failures }
    }

    func report(_ failure: HistoryStoreFailure) {
        lock.withLock { failures.append(failure) }
    }
}

@Suite struct HistoryFailureReportTests {
    let file: TemporaryHistoryFile
    let reported = ReportedFailures()
    let history: SQLiteHistoryRepository

    init() throws {
        file = try TemporaryHistoryFile()
        history = try SQLiteHistoryRepository(fileURL: file.fileURL, onFailure: reported.report)
    }

    @Test func successfulOperationsReportNothing() {
        history.record(ClipboardItem(text: "Ada Lovelace"))
        history.delete(ClipboardItem(text: "Ada Lovelace"))
        history.clearAll()

        #expect(history.items().isEmpty)
        #expect(reported.all.isEmpty)
    }

    @Test func writeThatFailsAfterOpenIsReportedOnce() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: file.directory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.directory.path)
        }

        history.record(ClipboardItem(text: "Ada Lovelace"))
        _ = history.items()

        #expect(reported.all.count == 1)
        #expect(reported.all.first.map { Self.isSQLiteFailure($0, operation: "record") } == true)
    }

    @Test func readThatFailsAfterOpenIsReported() throws {
        history.record(ClipboardItem(text: "Ada Lovelace"))
        _ = history.items()
        try Data(repeating: 0xA5, count: 4096).write(to: file.fileURL)

        #expect(history.items().isEmpty)
        #expect(reported.all == [.sqlite(operation: "items", resultCode: SQLITE_NOTADB)])
    }

    private static func isSQLiteFailure(_ failure: HistoryStoreFailure, operation expected: String) -> Bool {
        guard case .sqlite(let operation, _) = failure else { return false }
        return operation == expected
    }
}
