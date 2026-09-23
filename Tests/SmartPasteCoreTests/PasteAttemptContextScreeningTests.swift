import SmartPasteCore
import Testing

/// A suspected secret in the Target Context's surrounding text: the attempt proceeds without that window, every
/// request (retries too) omits it, and the outcome carries the visible note. Refusals never carry it.
@MainActor
struct PasteAttemptContextScreeningTests {
    static let chatWithSecret = BoundTarget(
        identity: TargetIdentity(processIdentifier: 42, elementToken: 11),
        context: TargetContext(fieldLabel: "Message", surroundingText: "ops: " + StubPreCheck.secretPrefix + "4f9a"),
        isSecureField: false
    )

    @Test func requestOmitsTheWithheldWindowAndTheInsertedOutcomeCarriesTheNote() {
        let harness = PasteAttemptHarness(focusedTarget: Self.chatWithSecret)

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.jev.requests.map(\.targetContext) == [TargetContext(fieldLabel: "Message")])
        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.presenter.notes == [.surroundingTextWithheld])
    }

    @Test func aRateLimitRetryAlsoOmitsTheWithheldWindow() {
        let harness = PasteAttemptHarness(focusedTarget: Self.chatWithSecret)

        harness.hotkey.press()
        harness.jev.reply(.rateLimited(retryAfter: .seconds(1)))
        harness.clock.advance(by: .seconds(1))

        #expect(
            harness.jev.requests.map(\.targetContext)
                == Array(repeating: TargetContext(fieldLabel: "Message"), count: 2))
    }

    @Test func noSuitableMatchAlsoCarriesTheNote() {
        let harness = PasteAttemptHarness(focusedTarget: Self.chatWithSecret)

        harness.hotkey.press()
        harness.jev.reply(.decided(Decision(choice: .noneOfThese, containsValueProbability: 0.1)))

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.presenter.notes == [.surroundingTextWithheld])
    }

    @Test func ordinarySurroundingTextCarriesNoNote() {
        let harness = PasteAttemptHarness()

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.presenter.notes == [nil])
    }

    @Test func aRefusalNeverCarriesTheNote() {
        let harness = PasteAttemptHarness(
            focusedTarget: Self.chatWithSecret, sourceText: StubPreCheck.secretPrefix + "item"
        )

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.refused(.suspectedSecret)])
        #expect(harness.presenter.notes == [nil])
    }
}
