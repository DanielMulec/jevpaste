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

    @Test func typesafeDirectsKeyIsItsOwnFileBesideTheGateways() throws {
        let store = FileJevKeyStore(directory: directory)

        try store.setAPIKey("fake-gateway-key", for: .vercelAIGateway)
        try store.setAPIKey("fake-typesafe-key", for: .typesafeDirect)

        #expect(try permissions(of: directory.appendingPathComponent("typesafeDirect")) == 0o600)
        #expect(FileJevKeyStore(directory: directory).apiKey(for: .typesafeDirect) == "fake-typesafe-key")
        #expect(FileJevKeyStore(directory: directory).apiKey(for: .vercelAIGateway) == "fake-gateway-key")
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

    @Test func anExistingLooserDirectoryIsTightenedToTheUserOnlyOnEveryWrite() throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755]
        )
        let store = FileJevKeyStore(directory: directory)

        try store.setAPIKey("fake-file-key-1", for: .vercelAIGateway)
        #expect(try permissions(of: directory) == 0o700)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        try store.setAPIKey("fake-file-key-2", for: .vercelAIGateway)
        #expect(try permissions(of: directory) == 0o700)
    }

    @Test func aDirectoryThatIsASymbolicLinkIsRefusedAndNothingIsWritten() throws {
        let elsewhere = base.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let parent = directory.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: elsewhere)

        #expect(throws: JevKeyStoreFailure.self) {
            try FileJevKeyStore(directory: self.directory).setAPIKey("fake-file-key", for: .vercelAIGateway)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty)
    }

    @Test func aKeyIsWrittenWholeAcrossShortAndInterruptedWrites() {
        var calls: [Int] = []
        var interrupted = false
        let result = FileJevKeyStore.writeAll(Array("fake-file-key".utf8)) { _, count in
            calls.append(count)
            if !interrupted {
                interrupted = true
                errno = EINTR
                return -1
            }
            return min(count, 4)
        }

        #expect(result == 0)
        #expect(calls == [13, 13, 9, 5, 1])
    }

    @Test(arguments: [(-1, EIO, EIO), (0, 0, EIO)])
    func aFailedOrStalledWriteIsANonZeroFailure(returned: Int, error: Int32, expected: Int32) {
        let result = FileJevKeyStore.writeAll(Array("fake-file-key".utf8)) { _, _ in
            errno = error
            return returned
        }

        #expect(result == expected)
    }

    @Test func aDirectoryThatCannotBeCreatedIsAReportedFailure() throws {
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try Data("not a directory".utf8).write(to: base.appendingPathComponent("config"))

        #expect(throws: JevKeyStoreFailure.self) {
            try FileJevKeyStore(directory: self.directory).setAPIKey("fake-file-key", for: .vercelAIGateway)
        }
    }
}
