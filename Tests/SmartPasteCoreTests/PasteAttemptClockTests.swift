import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptClockTests {
    @Test func slowJevShowsTheProcessingIndicatorAt150Milliseconds() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(149))
        #expect(harness.presenter.processingShownAt == nil)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.presenter.processingShownAt == .milliseconds(150))
    }

    @Test func slowJevTimesOutAtFiveSecondsIncludingARateLimitRetryInsideTheWindow() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(1))
        harness.jev.reply(.rateLimited(retryAfter: .seconds(1)))
        #expect(harness.presenter.retryingShownCount == 1)
        harness.clock.advance(by: .seconds(1))
        #expect(harness.jev.requests.count == 2)
        harness.clock.advance(by: .milliseconds(2999))
        #expect(harness.presenter.outcomes.isEmpty)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.presenter.outcomes == [.failed(.timedOut)])
    }

    @Test func rateLimitPushingPastFiveSecondsTimesOutWithoutRetry() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(2))
        harness.jev.reply(.rateLimited(retryAfter: .seconds(3)))

        #expect(harness.presenter.outcomes == [.failed(.timedOut)])
        harness.clock.advance(by: .seconds(10))
        #expect(harness.jev.requests.count == 1)
    }
}
