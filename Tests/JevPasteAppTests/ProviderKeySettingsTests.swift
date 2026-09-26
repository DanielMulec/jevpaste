import JevGateway
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// A provider's key row in Settings: every edit is saved to the Keychain and clears the Test result; Test sends one
/// cheap Jev call with the saved key and shows "✓ Works" or why not.
@MainActor
struct ProviderKeySettingsTests {
    private let keys = InMemoryJevKeyStore()
    private let tests = PendingConnectionTests()
    private let settings: ProviderKeySettings

    init() {
        settings = ProviderKeySettings(keys: keys) { [tests] provider, reply in tests.pending.append((provider, reply))
        }
    }

    @Test func anEditIsSavedAndAnEmptiedFieldRemovesTheKey() {
        settings.keyEdited("fake-key-1", for: .vercelAIGateway)
        #expect(keys.keys == [.vercelAIGateway: "fake-key-1"])
        #expect(settings.savedKey(of: .vercelAIGateway) == "fake-key-1")

        settings.keyEdited("", for: .vercelAIGateway)
        #expect(keys.keys.isEmpty)
    }

    @Test func testShowsTestingThenWorksWithTheProvidersName() throws {
        settings.keyEdited("fake-key-1", for: .vercelAIGateway)

        settings.test(.vercelAIGateway)
        #expect(settings.result(for: .vercelAIGateway) == .testing)
        try #require(tests.pending.first).reply(.works)

        #expect(tests.pending.map(\.provider) == [.vercelAIGateway])
        #expect(settings.result(for: .vercelAIGateway) == .works)
        #expect(
            ProviderKeyResult.works.text(for: .vercelAIGateway) == "✓ Works — Jev answered through Vercel AI Gateway.")
    }

    @Test func editingClearsTheResultAndALateAnswerToTheOldKeyIsDropped() throws {
        settings.keyEdited("fake-key-1", for: .vercelAIGateway)
        settings.test(.vercelAIGateway)

        settings.keyEdited("fake-key-2", for: .vercelAIGateway)
        try #require(tests.pending.first).reply(.failed(.keyRejected(status: 401)))

        #expect(settings.result(for: .vercelAIGateway) == .none)
    }

    @Test(arguments: [
        (JevConnectionTestFailure.noKey, "✕ No key saved"),
        (.keyRejected(status: 401), "✕ Key not accepted (HTTP 401)"),
        (.rateLimited, "✕ Jev asked us to wait — try again in a moment"),
        (.noConnection, "✕ No connection to Vercel AI Gateway"),
        (.httpStatus(500), "✕ Vercel AI Gateway answered HTTP 500"),
        (.unexpectedAnswer, "✕ Jev's answer was not the one offered"),
    ])
    func aFailedTestSaysWhy(failure: JevConnectionTestFailure, text: String) {
        #expect(ProviderKeyResult.failed(failure).text(for: .vercelAIGateway) == text)
    }

    @Test func aKeyTheKeychainRefusesSaysSoInTheResultSlot() {
        keys.failsWrites = true

        settings.keyEdited("fake-key-1", for: .vercelAIGateway)

        #expect(settings.result(for: .vercelAIGateway) == .notSaved(status: -25_299))
        #expect(
            ProviderKeyResult.notSaved(status: -25_299).text(for: .vercelAIGateway)
                == "✕ Could not save the key to the Keychain (error -25299)")
    }

    @Test func openedFromTheRefusalAMissingKeyIsNotedAtTheField() {
        settings.openedForMissingKey(of: .vercelAIGateway)
        #expect(settings.result(for: .vercelAIGateway) == .missingKey)
        #expect(
            ProviderKeyResult.missingKey.text(for: .vercelAIGateway)
                == "⚠︎ No key for Vercel AI Gateway — paste it here.")

        settings.keyEdited("fake-key-1", for: .vercelAIGateway)
        settings.openedForMissingKey(of: .vercelAIGateway)
        #expect(settings.result(for: .vercelAIGateway) == .none)
    }
}

/// Connection tests started from Settings, answered by the test.
@MainActor
final class PendingConnectionTests {
    var pending: [(provider: JevProvider, reply: @MainActor (JevConnectionTestResult) -> Void)] = []
}
