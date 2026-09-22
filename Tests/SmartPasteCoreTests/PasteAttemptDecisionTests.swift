import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptDecisionTests {
    @Test func noneOfTheseIsNoSuitableMatchWithNothingInserted() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.reply(.decided(Decision(choice: .noneOfThese, containsValueProbability: 0.9)))

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func containsValueProbabilityBelowOneHalfIsNoSuitableMatch() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.choose("ada@example.com", probability: 0.49)

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func jevErrorFailsAsDecisionUnavailable() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.reply(.failed)

        #expect(harness.presenter.outcomes == [.failed(.decisionUnavailable)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func noCandidatesIsNoSuitableMatchWithoutJevCall() {
        let harness = PasteAttemptHarness(candidates: [])

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.jev.requests.isEmpty)
    }

    @Test func nonSubstringJevAnswerFailsAsInvalidResult() {
        let harness = PasteAttemptHarness()

        harness.pasteChoosing("ada@evil.example")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func canonicallyEquivalentButDifferentlyEncodedAnswerFailsAsInvalidResult() {
        let harness = PasteAttemptHarness(
            candidates: [Candidate(text: "Z\u{FC}rich")], sourceText: "City: Z\u{FC}rich"
        )

        harness.pasteChoosing("Zu\u{308}rich")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
    }

    @Test func verbatimJevAnswerThatIsNotAnOfferedCandidateFailsAsInvalidResult() {
        let harness = PasteAttemptHarness()

        harness.pasteChoosing("Lovelace")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func differentlyEncodedFormOfAnOfferedCandidateFailsEvenWhenTheSourceContainsIt() {
        let harness = PasteAttemptHarness(
            candidates: [Candidate(text: "Z\u{FC}rich")], sourceText: "City: Z\u{FC}rich / Zu\u{308}rich"
        )

        harness.pasteChoosing("Zu\u{308}rich")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }
}
