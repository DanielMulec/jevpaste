import Foundation
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The one-time import at launch: the Vercel AI Gateway key from the env file moves into the Keychain once; after
/// that the env file is never consulted again, even when the Keychain key is later removed in Settings.
@MainActor
struct JevKeyImportTests {
    private let scratch = ScratchDefaults()
    private let envWithKey = "AI_GATEWAY_API_KEY=fake-env-key\n"

    @Test func theEnvFilesKeyIsStoredInTheKeychainOnce() throws {
        let keys = InMemoryJevKeyStore()
        let envFile = try temporaryEnvFile(containing: envWithKey)

        let first = JevKeyImport.runOnce(into: keys, from: envFile, remembering: scratch.defaults)
        try keys.setAPIKey("", for: .vercelAIGateway)
        let second = JevKeyImport.runOnce(into: keys, from: envFile, remembering: scratch.defaults)

        #expect(first == .imported)
        #expect(second == .alreadyDone)
        #expect(keys.keys.isEmpty)
    }

    @Test func aKeyAlreadyInTheKeychainIsKeptAndTheImportIsDone() throws {
        let keys = InMemoryJevKeyStore(keys: [.vercelAIGateway: "fake-keychain-key"])

        let result = JevKeyImport.runOnce(
            into: keys, from: try temporaryEnvFile(containing: envWithKey), remembering: scratch.defaults
        )

        #expect(result == .keychainHasKey)
        #expect(keys.keys == [.vercelAIGateway: "fake-keychain-key"])
        #expect(
            JevKeyImport.runOnce(
                into: keys, from: try temporaryEnvFile(containing: envWithKey),
                remembering: scratch.defaults) == .alreadyDone)
    }

    @Test(arguments: [nil, "OTHER=1\n"])
    func withoutAKeyInTheEnvFileNothingIsStoredAndTheImportIsDone(envText: String?) throws {
        let keys = InMemoryJevKeyStore()

        let first = JevKeyImport.runOnce(
            into: keys, from: try temporaryEnvFile(containing: envText), remembering: scratch.defaults
        )
        let later = JevKeyImport.runOnce(
            into: keys, from: try temporaryEnvFile(containing: envWithKey), remembering: scratch.defaults
        )

        #expect(first == .noEnvKey)
        #expect(later == .alreadyDone)
        #expect(keys.keys.isEmpty)
    }

    @Test func aFailedKeychainWriteIsRetriedAtTheNextLaunch() throws {
        let keys = InMemoryJevKeyStore()
        keys.failsWrites = true
        let envFile = try temporaryEnvFile(containing: envWithKey)

        let failed = JevKeyImport.runOnce(into: keys, from: envFile, remembering: scratch.defaults)
        keys.failsWrites = false
        let retried = JevKeyImport.runOnce(into: keys, from: envFile, remembering: scratch.defaults)

        #expect(failed == .failed)
        #expect(retried == .imported)
        #expect(keys.keys == [.vercelAIGateway: "fake-env-key"])
    }
}
