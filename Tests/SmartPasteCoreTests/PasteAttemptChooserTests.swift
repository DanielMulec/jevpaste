import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptChooserTests {
    /// Jev asks the user at step 1, weighting the two emails and — a little — the whole copy.
    private static func harnessWithChooserOpen() -> PasteAttemptHarness {
        let harness = PasteAttemptHarness()
        harness.hotkey.press()
        harness.jev.askUser(
            weighting: [("ada@work.example", 0.2), ("ada@example.com", 0.3), (PasteAttemptHarness.sourceText, 0.01)]
        )
        return harness
    }

    @Test func askTheUserOpensTheChooserWithEveryWeightedOptionMostLikelyFirst() {
        let harness = Self.harnessWithChooserOpen()

        let offered = ["ada@example.com", "ada@work.example", PasteAttemptHarness.sourceText]
        #expect(harness.chooser.offeredCandidates == offered.map { Candidate(text: $0) })
        #expect(harness.chooser.offeredTarget == PasteAttemptHarness.emailField)
        #expect(harness.presenter.outcomes.isEmpty)
    }

    @Test func askTheUserAtALaterStepOffersThatStepsOptions() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick("Email: ada@example.com")
        harness.jev.askUser(weighting: [("ada@example.com", 0.4), ("Email: ada@example.com", 0.2)])

        let offered = ["ada@example.com", "Email: ada@example.com"]
        #expect(harness.chooser.offeredCandidates == offered.map { Candidate(text: $0) })
    }

    @Test func choosingTheWholeCopyPastesItWithoutItsOuterLineBreaks() {
        let harness = PasteAttemptHarness(sourceText: "\nAda\nada@example.com\n")
        harness.hotkey.press()
        harness.jev.askUser(weighting: [("\nAda\nada@example.com\n", 0.3), ("ada@example.com", 0.2)])

        harness.chooser.choose("\nAda\nada@example.com\n")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write("Ada\nada@example.com"), .pasteKeystroke, .restore])
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

        harness.chooser.choose("Ada Lovelace")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func chooserReplyInADifferentEncodingOfAnOfferedAlternativeFails() {
        let harness = PasteAttemptHarness(sourceText: "Z\u{FC}rich, Zu\u{308}rich\nBern")
        harness.hotkey.press()
        harness.jev.askUser(weighting: [("Z\u{FC}rich", 0.3), ("Bern", 0.3)])

        harness.chooser.choose("Zu\u{308}rich")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.log.steps.isEmpty)
    }
}
