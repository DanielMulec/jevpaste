import SmartPasteCore
import Testing

/// Jev fills the Candidate Chooser after asking the user (Daniel, 2026-09-26): the fill choices run on the 5 s clock;
/// when the clock runs out or the Gateway fails mid-fill, the chooser opens with the rows found — with none, the
/// attempt ends as it would have at a step.
@MainActor
struct PasteAttemptChooserFillTests {
    private static let work = "ada@work.example"
    private static let home = "ada@example.com"

    /// ⌘⇧V, Jev asks the user and has found `rows` so far; the next fill choice is outstanding.
    private static func filling(found rows: [String]) -> PasteAttemptHarness {
        let harness = PasteAttemptHarness()
        harness.hotkey.press()
        harness.jev.askUser(probability: 0.71, weighting: [])
        for row in rows { harness.jev.pick(row) }
        return harness
    }

    @Test func theChooserOffersJevsFillPicksInTheOrderFound() {
        let harness = Self.filling(found: [])

        harness.jev.fillChooser(with: [Self.work, Self.home])

        #expect(harness.chooser.offeredCandidates == [Candidate(text: Self.work), Candidate(text: Self.home)])
        #expect(harness.jev.requests.count == 4)
        #expect(
            harness.jev.requests.dropFirst().allSatisfy { request in
                request.questions.allSatisfy { !$0.options.map(\.id).contains("ask_user") }
            })
    }

    @Test func theFillCallsAreOnTheClockAndItsEndOpensTheChooserWithTheRowsFound() {
        let harness = Self.filling(found: [Self.home])

        harness.clock.advance(by: .seconds(5))
        harness.jev.nothingFits()

        #expect(harness.chooser.offeredCandidates == [Candidate(text: Self.home)])
        #expect(harness.presenter.outcomes.isEmpty)
        harness.chooser.choose(Self.home)
        harness.clock.advance(by: .milliseconds(120))
        let path = harness.presenter.paths.last ?? nil
        #expect(harness.presenter.outcomes == [.inserted])
        #expect(path?.narrowing.chooserFill == ChooserFillTrace(calls: 2, end: .clock))
        #expect(path?.narrowing.decidingProbability == 0.71)
        #expect(path?.calls == 3)
    }

    @Test func theClockRunningOutBeforeTheFirstRowIsATimeout() {
        let harness = Self.filling(found: [])

        harness.clock.advance(by: .seconds(5))

        #expect(harness.presenter.outcomes == [.failed(.timedOut)])
        #expect(harness.chooser.offeredCandidates == nil)
    }

    @Test(arguments: [NarrowingReply.failed, .tooLarge])
    func aGatewayFailureMidFillOpensTheChooserWithTheRowsFound(reply: NarrowingReply) {
        let harness = Self.filling(found: [Self.work])

        harness.jev.reply(reply)

        #expect(harness.chooser.offeredCandidates == [Candidate(text: Self.work)])
        harness.chooser.dismiss()
        let path = harness.presenter.paths.last ?? nil
        #expect(path?.narrowing.chooserFill == ChooserFillTrace(calls: 2, end: .failed))
    }

    @Test func aGatewayFailureBeforeTheFirstRowFailsAsAtAStep() {
        let harness = Self.filling(found: [])

        harness.jev.reply(.failed)

        #expect(harness.presenter.outcomes == [.failed(.decisionUnavailable)])
        #expect(harness.chooser.offeredCandidates == nil)
    }

    @Test func aRateLimitWaitPastTheClockMidFillOpensTheChooserWithTheRowsFound() {
        let harness = Self.filling(found: [Self.work])

        harness.jev.reply(.rateLimited(retryAfter: .seconds(6)))

        #expect(harness.chooser.offeredCandidates == [Candidate(text: Self.work)])
        #expect(harness.presenter.outcomes.isEmpty)
    }
}
