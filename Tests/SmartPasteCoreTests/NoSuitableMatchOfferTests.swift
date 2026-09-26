import SmartPasteCore
import Testing

/// After No Suitable Match — Jev choosing "nothing fits" at any Narrowing step — the attempt offers Enter to paste the
/// whole Active Item as a Direct Paste. Only Enter inserts; Esc, click-away, ⌘⇧V or the 8 s offer timeout end the
/// attempt with nothing inserted.
@MainActor
struct NoSuitableMatchOfferTests {
    private static func harnessOffering(sourceText: String = PasteAttemptHarness.sourceText) -> PasteAttemptHarness {
        let harness = PasteAttemptHarness(sourceText: sourceText)
        harness.hotkey.press()
        harness.jev.nothingFits()
        return harness
    }

    @Test func nothingFitsOffersThePasteForTheBoundTargetWithoutEndingTheAttempt() {
        let harness = Self.harnessOffering()

        #expect(harness.presenter.offeredTargets == [PasteAttemptHarness.emailField])
        #expect(harness.presenter.outcomes.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }

    @Test func nothingFitsAtALaterStepAlsoOffersThePasteOfTheWholeItem() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick("Email: ada@example.com")
        harness.jev.nothingFits()
        harness.presenter.acceptOffer()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write(PasteAttemptHarness.sourceText), .pasteKeystroke, .restore])
        #expect(harness.presenter.paths.map { $0?.noSuitableMatchOfferEnd } == [.accepted])
    }

    @Test func theOfferIsOffTheFiveSecondClock() {
        let harness = Self.harnessOffering()

        harness.clock.advance(by: .milliseconds(7900))

        #expect(harness.presenter.outcomes.isEmpty)
        #expect(harness.presenter.processingShownAt == nil)
    }

    @Test func enterPastesTheWholeItemWithOuterLineBreaksStripped() {
        let harness = Self.harnessOffering(sourceText: "\r\n" + PasteAttemptHarness.sourceText + "\n\n")

        harness.presenter.acceptOffer()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.paths.map { $0?.noSuitableMatchOfferEnd } == [.accepted])
        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.log.steps == [.write(PasteAttemptHarness.sourceText), .pasteKeystroke, .restore])
    }

    @Test func enterWaitsForFocusToReturnToTheTargetsAppBeforePasting() {
        let harness = Self.harnessOffering()

        harness.presenter.pressOfferKey(accepting: true)
        #expect(harness.log.steps.isEmpty)
        #expect(harness.presenter.outcomes.isEmpty)
        harness.presenter.finishFocusReturn()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
    }

    /// Adversarial: a misbehaving adapter answers twice; the second answer finds the attempt already delivering.
    @Test func aSecondAnswerToTheSameOfferIsIgnored() {
        let harness = Self.harnessOffering()
        let callbacks = harness.presenter.newestOfferCallbacks

        callbacks?.accept()
        callbacks?.dismiss()
        callbacks?.accept()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.log.steps.count == 3)
    }

    @Test func escapeInsertsNothingAndEndsAsNoSuitableMatch() {
        let harness = Self.harnessOffering()

        harness.presenter.dismissOffer()
        harness.clock.advance(by: .seconds(10))

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.presenter.paths.map { $0?.noSuitableMatchOfferEnd } == [.dismissed])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func theOfferTimesOutAfterEightSecondsWithNothingInserted() {
        let harness = Self.harnessOffering()

        harness.clock.advance(by: .milliseconds(7999))
        #expect(harness.presenter.outcomes.isEmpty)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.presenter.paths.map { $0?.noSuitableMatchOfferEnd } == [.timedOut])
        #expect(harness.log.steps.isEmpty)
    }

    /// Adversarial: a misbehaving adapter calls the withdrawn offer's accept after the attempt timed out.
    @Test func aStaleAcceptAfterTheOfferTimedOutIsIgnored() {
        let harness = Self.harnessOffering()
        let staleAccept = harness.presenter.newestOfferCallbacks?.accept
        harness.clock.advance(by: .seconds(8))

        staleAccept?()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.log.steps.isEmpty)
    }

    /// Adversarial for the accept: the withdrawn offer's accept is called after ⌘⇧V ended it.
    @Test func aHotkeyPressDuringTheOfferEndsItWithoutStartingANewAttempt() {
        let harness = Self.harnessOffering()
        let staleAccept = harness.presenter.newestOfferCallbacks?.accept

        harness.hotkey.press()
        staleAccept?()

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.presenter.paths.map { $0?.noSuitableMatchOfferEnd } == [.dismissed])
        #expect(harness.jev.requests.count == 1)
        #expect(harness.log.steps.isEmpty)
    }

    @Test func enterAfterTheTargetChangedFailsVisiblyWithNothingInserted() {
        let harness = Self.harnessOffering()

        harness.targetResolver.focusedTarget = nil
        harness.presenter.acceptOffer()

        #expect(harness.presenter.outcomes == [.failed(.targetChanged)])
        #expect(harness.presenter.paths.map { $0?.noSuitableMatchOfferEnd } == [.accepted])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func theNextHotkeyPressAfterTheOfferEndedStartsAFreshAttempt() {
        let harness = Self.harnessOffering()
        harness.presenter.dismissOffer()

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.noSuitableMatch, .inserted])
        #expect(harness.presenter.paths.map { $0?.noSuitableMatchOfferEnd } == [.dismissed, nil])
    }

    @Test func theNarrowingTraceIsKeptWithHowTheOfferEnded() {
        let harness = PasteAttemptHarness()
        harness.hotkey.press()
        harness.jev.nothingFits(probability: 0.88)

        harness.presenter.dismissOffer()

        let trace = NarrowingTrace(
            steps: [.init(questions: 1, followUpSpeculativeQuestions: nil, isSpeculative: false)],
            decidingProbability: 0.88
        )
        #expect(
            harness.presenter.paths == [SmartPastePath(narrowing: trace, calls: 1, noSuitableMatchOfferEnd: .dismissed)]
        )
    }
}
