import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptChooserTests {
    private static func harnessWithChooserOpen() -> PasteAttemptHarness {
        let harness = PasteAttemptHarness(sameTypeGroup: PasteAttemptHarness.emailCandidates)
        harness.pasteChoosing("ada@example.com")
        return harness
    }

    @Test func chooserCancelInsertsNothing() {
        let harness = Self.harnessWithChooserOpen()

        #expect(harness.chooser.offeredCandidates == PasteAttemptHarness.emailCandidates)
        #expect(harness.chooser.offeredTarget == PasteAttemptHarness.emailField)
        harness.chooser.dismiss()

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func chooserChoiceDeliversTheChosenCandidate() {
        let harness = Self.harnessWithChooserOpen()

        harness.chooser.choose("ada@work.example")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write("ada@work.example"), .pasteKeystroke, .restore])
        #expect(harness.presenter.outcomes == [.inserted])
    }

    @Test func chooserChoiceReverifiesTheBoundTargetBeforeDelivery() {
        let harness = Self.harnessWithChooserOpen()

        harness.targetResolver.focusedTarget = nil
        harness.chooser.choose("ada@work.example")

        #expect(harness.presenter.outcomes == [.failed(.targetChanged)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func chooserKeepsTheClockStoppedWhileOpen() {
        let harness = Self.harnessWithChooserOpen()

        harness.clock.advance(by: .seconds(60))
        #expect(harness.clock.pendingTimerCount == 0)
        #expect(harness.presenter.outcomes.isEmpty)
        harness.chooser.choose("ada@work.example")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
    }

    @Test func chooserReplyThatIsNotAnOfferedAlternativeFailsAsInvalidResult() {
        let harness = Self.harnessWithChooserOpen()

        harness.chooser.choose("Ada Lovelace")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func chooserReplyInADifferentEncodingOfAnOfferedAlternativeFails() {
        let composed = Candidate(text: "Z\u{FC}rich")
        let alternatives = [composed, Candidate(text: "Bern")]
        let harness = PasteAttemptHarness(
            candidates: alternatives, sameTypeGroup: alternatives, sourceText: "Z\u{FC}rich, Zu\u{308}rich, Bern"
        )
        harness.pasteChoosing(composed.text)

        harness.chooser.choose("Zu\u{308}rich")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }
}
