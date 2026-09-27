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
    private let excluded = ExcludedTexts()
    private let settings: ProviderKeySettings

    init() {
        settings = ProviderKeySettings(
            keys: keys, excludeFromHistory: { [excluded] in excluded.texts.append($0) },
            runTest: { [tests] provider, reply in tests.pending.append((provider, reply)) }
        )
    }

    /// A key is usually copied — and so recorded in Clipboard History — before it is pasted here. Once the field is
    /// left (or tested, or Settings closes) the saved key is taken out of history; intermediate keystrokes are not.
    @Test func whenEditingEndsTheSavedKeyIsTakenOutOfHistory() {
        settings.keyEdited("f", for: .typesafeDirect)
        settings.keyEdited("fake-typesafe-key-54", for: .typesafeDirect)
        #expect(excluded.texts.isEmpty)

        settings.editingEnded(for: .typesafeDirect)

        #expect(excluded.texts == ["fake-typesafe-key-54"])
    }

    @Test func testingAlsoTakesTheSavedKeyOutOfHistory() {
        settings.keyEdited("fake-typesafe-key-54", for: .typesafeDirect)

        settings.test(.typesafeDirect)

        #expect(excluded.texts == ["fake-typesafe-key-54"])
    }

    @Test func anEmptiedFieldTakesNothingOutOfHistory() {
        settings.keyEdited("", for: .typesafeDirect)

        settings.editingEnded(for: .typesafeDirect)

        #expect(excluded.texts.isEmpty)
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

    /// Every result names the provider it tested, so Typesafe direct's row never reads like the Gateway's.
    @Test(arguments: [
        (JevConnectionTestFailure.noKey, "✕ No key saved for Typesafe direct"),
        (.keyRejected(status: 403), "✕ Typesafe direct did not accept the key (HTTP 403)"),
        (.rateLimited, "✕ Typesafe direct asked us to wait — try again in a moment"),
        (.noConnection, "✕ No connection to Typesafe direct"),
        (.httpStatus(422), "✕ Typesafe direct answered HTTP 422"),
        (.unexpectedAnswer, "✕ Jev's answer through Typesafe direct was not the one offered"),
    ])
    func aFailedTestSaysWhyAndNamesTheProvider(failure: JevConnectionTestFailure, text: String) {
        #expect(ProviderKeyResult.failed(failure).text(for: .typesafeDirect) == text)
    }

    @Test func theGatewaysRowNamesTheGateway() {
        #expect(
            ProviderKeyResult.failed(.keyRejected(status: 401)).text(for: .vercelAIGateway)
                == "✕ Vercel AI Gateway did not accept the key (HTTP 401)")
        #expect(
            ProviderKeyResult.works.text(for: .typesafeDirect) == "✓ Works — Jev answered through Typesafe direct.")
    }

    @Test func aKeyThatCannotBeSavedSaysSoInTheResultSlot() {
        keys.failsWrites = true

        settings.keyEdited("fake-key-1", for: .vercelAIGateway)

        #expect(settings.result(for: .vercelAIGateway) == .notSaved(code: 13))
        #expect(
            ProviderKeyResult.notSaved(code: 13).text(for: .vercelAIGateway) == "✕ Could not save the key (error 13)")
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

final class ExcludedTexts {
    var texts: [String] = []
}
