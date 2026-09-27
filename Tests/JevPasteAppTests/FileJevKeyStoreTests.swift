import Foundation
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The API keys as files readable by the user only: one file per Jev Provider in a 0700 directory, written atomically,
/// removed when the key is emptied.
@MainActor
final class FileJevKeyStoreTests {
    private let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("jevpaste-keys-\(UUID().uuidString)", isDirectory: true)
    private var directory: URL { base.appendingPathComponent("config/keys", isDirectory: true) }

    deinit {
        try? FileManager.default.removeItem(at: base)
    }

    private func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attributes[.posixPermissions] as? Int)
    }

    @Test func aStoredKeyIsReadBackAndOtherProvidersHaveNone() throws {
        let store = FileJevKeyStore(directory: directory)

        try store.setAPIKey("fake-file-key", for: .vercelAIGateway)

        #expect(FileJevKeyStore(directory: directory).apiKey(for: .vercelAIGateway) == "fake-file-key")
        #expect(store.apiKey(for: .typesafeDirect) == nil)
    }

    @Test func theMissingDirectoryIsCreatedForTheUserOnlyAndTheFileIsReadableByTheUserOnly() throws {
        try FileJevKeyStore(directory: directory).setAPIKey("fake-file-key", for: .vercelAIGateway)

        #expect(try permissions(of: directory) == 0o700)
        #expect(try permissions(of: directory.appendingPathComponent("vercelAIGateway")) == 0o600)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["vercelAIGateway"])
    }

    @Test func aReplacedKeyKeepsTheFileReadableByTheUserOnly() throws {
        let store = FileJevKeyStore(directory: directory)

        try store.setAPIKey("fake-file-key-1", for: .vercelAIGateway)
        try store.setAPIKey("fake-file-key-2", for: .vercelAIGateway)

        #expect(store.apiKey(for: .vercelAIGateway) == "fake-file-key-2")
        #expect(try permissions(of: directory.appendingPathComponent("vercelAIGateway")) == 0o600)
    }

    @Test func anEmptiedKeyRemovesTheFileAndRemovingNothingIsFine() throws {
        let store = FileJevKeyStore(directory: directory)
        try store.setAPIKey("fake-file-key", for: .vercelAIGateway)

        try store.setAPIKey("", for: .vercelAIGateway)
        try store.setAPIKey("", for: .typesafeDirect)

        #expect(store.apiKey(for: .vercelAIGateway) == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("vercelAIGateway").path))
    }

    @Test func aDirectoryThatCannotBeCreatedIsAReportedFailure() throws {
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try Data("not a directory".utf8).write(to: base.appendingPathComponent("config"))

        #expect(throws: JevKeyStoreFailure.self) {
            try FileJevKeyStore(directory: self.directory).setAPIKey("fake-file-key", for: .vercelAIGateway)
        }
    }
}
