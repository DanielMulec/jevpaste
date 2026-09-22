import Foundation
import HistoryStore
import SQLite3
import SmartPasteCore
import Testing

@Suite struct HistoryFileTests {
    let file: TemporaryHistoryFile

    init() throws {
        file = try TemporaryHistoryFile()
    }

    private func posixPermissions(of url: URL) throws -> Int? {
        try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
    }

    @Test func itemsSurviveReopeningTheSameFile() throws {
        var history: (any HistoryRepository)? = try file.openRepository()
        history?.record(ClipboardItem(text: "Ada Lovelace"))
        history?.record(ClipboardItem(text: "ada@example.org"))
        _ = history?.items()
        history = nil

        let reopened = try file.openRepository()

        #expect(reopened.items().map(\.text) == ["ada@example.org", "Ada Lovelace"])
    }

    @Test func productionFileLivesInApplicationSupportJevpaste() {
        let url = HistoryStoreLocation.defaultFileURL

        #expect(url.lastPathComponent == "history.sqlite")
        #expect(url.deletingLastPathComponent().lastPathComponent == "jevpaste")
        #expect(url.deletingLastPathComponent().deletingLastPathComponent() == URL.applicationSupportDirectory)
    }

    @Test func absentDirectoriesAreCreatedReadableByTheUserOnly() throws {
        let nestedDirectory = file.directory.appendingPathComponent("a/jevpaste", isDirectory: true)
        let fileURL = nestedDirectory.appendingPathComponent("history.sqlite")

        let history = try SQLiteHistoryRepository(fileURL: fileURL)
        history.record(ClipboardItem(text: "Ada Lovelace"))

        #expect(history.items().count == 1)
        #expect(try posixPermissions(of: nestedDirectory) == 0o700)
    }

    @Test func newFileIsReadableAndWritableByTheUserOnly() throws {
        _ = try file.openRepository()

        #expect(try posixPermissions(of: file.fileURL) == 0o600)
    }

    @Test func existingFileWithLooserPermissionsIsTightened() throws {
        _ = try file.openRepository()
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.fileURL.path)

        _ = try file.openRepository()

        #expect(try posixPermissions(of: file.fileURL) == 0o600)
    }

    @Test func corruptFileMakesOpeningThrowNotADatabase() throws {
        try Data(repeating: 0xA5, count: 4096).write(to: file.fileURL)

        #expect(throws: HistoryStoreFailure.sqlite(operation: "readSchemaVersion", resultCode: SQLITE_NOTADB)) {
            try file.openRepository()
        }
    }

    @Test func directoryInPlaceOfTheFileMakesOpeningThrow() throws {
        try FileManager.default.createDirectory(at: file.fileURL, withIntermediateDirectories: false)

        #expect(throws: HistoryStoreFailure.self) {
            try file.openRepository()
        }
    }

    @Test func fileInPlaceOfTheDirectoryMakesOpeningThrowDirectoryUnavailable() throws {
        let blockingFile = file.directory.appendingPathComponent("jevpaste")
        try Data("not a directory".utf8).write(to: blockingFile)

        #expect(throws: HistoryStoreFailure.directoryUnavailable) {
            try SQLiteHistoryRepository(fileURL: blockingFile.appendingPathComponent("history.sqlite"))
        }
    }

    @Test func fileFromANewerSchemaIsRefusedAndLeftUntouched() throws {
        var connection: OpaquePointer?
        #expect(sqlite3_open(file.fileURL.path, &connection) == SQLITE_OK)
        #expect(sqlite3_exec(connection, "PRAGMA user_version = 2", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(connection)

        #expect(throws: HistoryStoreFailure.unsupportedSchemaVersion(2)) {
            try file.openRepository()
        }
    }
}
