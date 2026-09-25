import SmartPasteCore
import Testing

/// Replies and timers that belong to an ended Paste Attempt must not touch the next one.
@MainActor
struct PasteAttemptStaleEventTests {
    @Test func lateJevReplyAfterTimeoutIsIgnoredByTheNextAttempt() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(5))
        harness.hotkey.press()
        harness.jev.choose("ada@example.com")

        #expect(harness.presenter.outcomes == [.failed(.timedOut)])
        #expect(harness.log.steps.isEmpty)
        harness.jev.choose("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))
        #expect(harness.presenter.outcomes == [.failed(.timedOut), .inserted])
    }

    @Test func lateJevReplyAfterEscapeIsIgnoredByTheNextAttempt() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        harness.presenter.pressEscape()
        harness.hotkey.press()
        harness.jev.reply(.rateLimited(retryAfter: .seconds(1)))

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.presenter.retryingShownCount == 0)
        harness.jev.choose("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))
        #expect(harness.presenter.outcomes == [.cancelled, .inserted])
    }

    @Test func staleDeadlineTimerFiringAfterAFreshAttemptStartedIsIgnored() {
        let harness = PasteAttemptHarness()
        harness.clock.ignoresCancellation = true

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(1))
        harness.jev.reply(.decided(Decision(choice: .noneOfThese, containsValueProbability: 0.9)))
        harness.presenter.dismissOffer()
        harness.hotkey.press()
        harness.clock.advance(by: .seconds(4))

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        harness.clock.advance(by: .seconds(1))
        #expect(harness.presenter.outcomes == [.noSuitableMatch, .failed(.timedOut)])
    }
}
