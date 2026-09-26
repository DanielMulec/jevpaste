import Foundation
import HistoryStore
import SmartPasteCore
import Testing

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

    /// Puts a copy of a file from `Fixtures/` where the repository opens its file.
    func copyFixture(named name: String) throws {
        let fixture = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: fixture, to: fileURL)
    }
}

/// Most tests only care about order and text: they record with a fixed copy time and read the items back.
extension HistoryRepository {
    func record(_ item: ClipboardItem) {
        record(item, copiedAt: Date(timeIntervalSince1970: 1_790_000_000))
    }

    func items() -> [ClipboardItem] {
        entries().map(\.item)
    }
}
