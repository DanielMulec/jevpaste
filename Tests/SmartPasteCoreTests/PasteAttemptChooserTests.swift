import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptChooserTests {
    /// Jev asks the user at step 1 and fills the chooser with the two emails, the backup first.
    private static func harnessWithChooserOpen() -> PasteAttemptHarness {
        let harness = PasteAttemptHarness()
        harness.hotkey.press()
        harness.jev.askUser(weighting: [("ada@example.com", 0.3)])
        harness.jev.fillChooser(with: ["ada@work.example", "ada@example.com"])
        return harness
    }

    @Test func askTheUserOpensTheChooserForTheBoundTargetWithJevsRows() {
        let harness = Self.harnessWithChooserOpen()

        let offered = ["ada@work.example", "ada@example.com"]
        #expect(harness.chooser.offeredCandidates == offered.map { Candidate(text: $0) })
        #expect(harness.chooser.offeredTarget == PasteAttemptHarness.emailField)
        #expect(harness.presenter.outcomes.isEmpty)
    }

    @Test func askTheUserAtALaterStepFillsTheChooserFromThatStepsPiece() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick("Email: ada@example.com")
        harness.jev.askUser(weighting: [])
        harness.jev.fillChooser(with: ["ada@example.com"])

        #expect(harness.chooser.offeredCandidates == [Candidate(text: "ada@example.com")])
        #expect(harness.jev.requests.count == 4)
    }

    @Test func chooserCancelInsertsNothing() {
        let harness = Self.harnessWithChooserOpen()

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

        harness.chooser.replyAsAMisbehavingAdapter(with: "Ada Lovelace")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func aSecondReplyAfterTheChooserAnsweredIsIgnored() {
        let harness = Self.harnessWithChooserOpen()
        harness.chooser.dismiss()

        harness.chooser.replyAsAMisbehavingAdapter(with: "ada@work.example")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func chooserReplyInADifferentEncodingOfAnOfferedAlternativeFails() {
        let harness = PasteAttemptHarness(sourceText: "Z\u{FC}rich, Zu\u{308}rich\nBern")
        harness.hotkey.press()
        harness.jev.askUser(weighting: [])
        harness.jev.fillChooser(with: ["Z\u{FC}rich", "Bern"])

        harness.chooser.replyAsAMisbehavingAdapter(with: "Zu\u{308}rich")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }
}
