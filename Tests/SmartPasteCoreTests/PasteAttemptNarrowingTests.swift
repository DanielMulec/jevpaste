import SmartPasteCore
import Testing

/// Narrowing inside a Paste Attempt, step by step: what each step asks, how every pick is checked, and every way
/// Narrowing ends. Clock, rate limits and cancelling across steps: `PasteAttemptNarrowingClockTests`.
@MainActor
struct PasteAttemptNarrowingTests {
    private static let email = "Email: ada@example.com"

    @Test func keepingTheWholeCopyAtStepOnePastesItWithoutItsOuterLineBreaks() {
        let harness = PasteAttemptHarness(sourceText: "\n\nAda\n\nada@example.com \n")

        harness.hotkey.press()
        harness.jev.keep()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write("Ada\n\nada@example.com "), .pasteKeystroke, .restore])
        #expect(harness.presenter.outcomes == [.inserted])
    }

    @Test func aPickedPieceIsAskedAgainOnItsOwnWithTheLaterStepWording() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick(Self.email)

        let laterStep = harness.jev.requests.dropFirst().first
        #expect(harness.jev.requests.count == 2)
        #expect(laterStep?.sourceDocument == PasteAttemptHarness.sourceText)
        #expect(laterStep?.targetContext == TargetContext(fieldLabel: "Email"))
        let question = NarrowingPolicy.r2b.wordings.laterStepWithExcerptIDs
        #expect(laterStep?.questions.map(\.instructions) == [.onPiece(currentPiece: Self.email, question: question)])
        #expect(harness.presenter.outcomes.isEmpty)
    }

    @Test func aKeptPieceIsPastedAsItIsAndThePathCountsTheStepsAndCalls() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick(Self.email)
        harness.jev.keep(probability: 0.93)
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write(Self.email), .pasteKeystroke, .restore])
        let path = harness.presenter.paths.last ?? nil
        #expect(path?.calls == 2)
        #expect(path?.narrowing.steps.map(\.questions) == [1, 1])
        #expect(path?.narrowing.decidingProbability == 0.93)
        #expect(path?.narrowing.steps.map(\.chosenProbability) == [0.9, 0.93])
    }

    @Test func aPickedSingleCharacterIsPastedWithoutAnotherCall() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick("@")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.jev.requests.count == 1)
        #expect(harness.log.steps == [.write("@"), .pasteKeystroke, .restore])
    }

    @Test func aSingleCharacterCopyIsStillAskedAtStepOne() {
        let harness = PasteAttemptHarness(sourceText: "x")

        harness.hotkey.press()

        #expect(
            harness.jev.requests.first?.questions.first?.options.map(\.id) == [
                "everything", "nothing_fits", "ask_user",
            ])
        #expect(harness.presenter.outcomes.isEmpty)
    }

    @Test func aCopyOfOnlyWhitespaceIsNoSuitableMatchWithoutACallOrOffer() {
        let harness = PasteAttemptHarness(sourceText: " \n\t\n ")

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.jev.requests.isEmpty)
        #expect(harness.presenter.offeredTargets.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }

    @Test func aPickThatWasNotOfferedFailsAsInvalidResultWithNothingPasted() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick(Self.email)
        harness.jev.pick("Name: Ada Lovelace")

        #expect(harness.presenter.outcomes == [.failed(.invalidResult)])
        #expect(harness.jev.requests.count == 2)
        #expect(harness.log.steps.isEmpty)
    }

    @Test func aFailedCallAtALaterStepFailsAsDecisionUnavailableWithNothingPasted() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick(Self.email)
        harness.jev.reply(.failed)

        #expect(harness.presenter.outcomes == [.failed(.decisionUnavailable)])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func jevRefusingTheSizeFailsAsTooLongForSmartPasteWithoutAnOffer() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.reply(.tooLarge)

        #expect(harness.presenter.outcomes == [.failed(.tooLongForSmartPaste)])
        #expect(harness.presenter.offeredTargets.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }
}

/// The 5 s clock, rate limits and a click across the steps of Narrowing.
@MainActor
struct PasteAttemptNarrowingClockTests {
    private static let email = "Email: ada@example.com"

    @Test func theFiveSecondClockRunsAcrossEveryStepFromTheBoundTarget() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(3))
        harness.jev.pick(Self.email)
        harness.clock.advance(by: .milliseconds(1999))
        #expect(harness.presenter.outcomes.isEmpty)
        harness.clock.advance(by: .milliseconds(1))
        #expect(harness.presenter.outcomes == [.failed(.timedOut)])
        harness.jev.keep()
        harness.clock.advance(by: .seconds(1))

        #expect(harness.log.steps.isEmpty)
    }

    @Test func aRateLimitAtALaterStepResendsThatStepsRequestAndCountsTheCall() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.pick(Self.email)
        harness.jev.reply(.rateLimited(retryAfter: .milliseconds(500)))
        harness.clock.advance(by: .milliseconds(500))
        let requests = harness.jev.requests
        harness.jev.keep()
        harness.clock.advance(by: .milliseconds(120))

        #expect(requests.count == 3)
        #expect(requests.last == requests.dropLast().last)
        #expect(harness.log.steps == [.write(Self.email), .pasteKeystroke, .restore])
        #expect((harness.presenter.paths.last ?? nil)?.calls == 3)
    }

    @Test func aClickBetweenStepsCancelsAndTheLateReplyIsIgnored() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        harness.jev.pick(Self.email)
        harness.presenter.clickIndicator()
        harness.jev.keep()
        harness.clock.advance(by: .seconds(1))

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.jev.requests.count == 2)
        #expect(harness.log.steps.isEmpty)
    }
}
