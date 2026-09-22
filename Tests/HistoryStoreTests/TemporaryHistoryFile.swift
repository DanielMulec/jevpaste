import Foundation
import HistoryStore
import SmartPasteCore

/// A history file inside a fresh temporary directory, removed when the value is deinitialised.
final class TemporaryHistoryFile {
    let directory: URL
    let fileURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("history.sqlite")
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func openRepository(retentionLimit: Int = 500) throws -> any HistoryRepository {
        try SQLiteHistoryRepository(fileURL: fileURL, retentionLimit: retentionLimit)
    }
}
