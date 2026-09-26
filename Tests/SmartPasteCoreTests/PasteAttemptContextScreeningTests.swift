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

        #expect(
            harness.jev.requests.map(\.targetContext)
                == Array(repeating: TargetContext(fieldLabel: "Message"), count: 2))
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
        harness.jev.nothingFits()
        harness.presenter.dismissOffer()

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

    /// Every way a screened attempt can finish, driven from ⌘⇧V.
    enum FinishPath: CaseIterable {
        case timeout, decisionUnavailable, invalidResult, targetChanged, chooserCancel, indicatorClick

        var outcome: PasteAttemptOutcome {
            switch self {
            case .timeout: .failed(.timedOut)
            case .decisionUnavailable: .failed(.decisionUnavailable)
            case .invalidResult: .failed(.invalidResult)
            case .targetChanged: .failed(.targetChanged)
            case .chooserCancel, .indicatorClick: .cancelled
            }
        }

        @MainActor func drive() -> PasteAttemptHarness {
            let harness = PasteAttemptHarness(focusedTarget: PasteAttemptContextScreeningTests.chatWithSecret)
            harness.hotkey.press()
            switch self {
            case .timeout: harness.clock.advance(by: .seconds(5))
            case .decisionUnavailable: harness.jev.reply(.failed)
            case .invalidResult: harness.jev.pick("not in the item")
            case .targetChanged:
                harness.targetResolver.focusedTarget = nil
                harness.jev.narrow(to: "Ada Lovelace")
            case .chooserCancel:
                harness.jev.askUser(weighting: [("ada@example.com", 0.3), ("ada@work.example", 0.3)])
                harness.chooser.dismiss()
            case .indicatorClick:
                harness.clock.advance(by: .milliseconds(150))
                harness.presenter.clickIndicator()
            }
            return harness
        }
    }

    @Test(arguments: FinishPath.allCases)
    func everyFinishPathCarriesTheNote(path: FinishPath) {
        let harness = path.drive()

        #expect(harness.presenter.outcomes == [path.outcome])
        #expect(harness.presenter.notes == [.surroundingTextWithheld])
    }
}
