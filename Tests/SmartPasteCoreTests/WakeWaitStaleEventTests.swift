import SmartPasteCore
import Testing

/// Clicks, callbacks and timers that belong to a Wake Wait that ended, or to an indicator not showing, change nothing.
@MainActor
struct WakeWaitStaleEventTests {
    @Test func aClickBeforeTheWakingIndicatorShowsDoesNotCancel() {
        let harness = PasteAttemptHarness(unreadableReads: 3)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(100))
        harness.presenter.clickIndicator()
        harness.clock.advance(by: .milliseconds(50))

        #expect(harness.presenter.outcomes.isEmpty)
        #expect(harness.jev.requests.count == 1)
    }

    @Test func aStaleWakingCancelAfterTheCancelAndAfterTheNextAttemptStartedDoesNothing() {
        let harness = PasteAttemptHarness(unreadableReads: .max)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        let staleCancel = harness.presenter.newestCancelCallback
        harness.presenter.clickIndicator()
        staleCancel?()
        harness.hotkey.press()
        staleCancel?()
        harness.clock.advance(by: .milliseconds(150))
        staleCancel?()

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.presenter.wakingApplicationNames.count == 2)
    }

    @Test func staleWakeWaitTimersFiringAfterTheNextAttemptStartedAreIgnored() {
        let harness = PasteAttemptHarness(unreadableReads: .max)
        harness.clock.ignoresCancellation = true

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))  // reads at 0, 50, 100, 150; waking shown
        harness.presenter.clickIndicator()
        harness.hotkey.press()  // read 5
        harness.clock.advance(by: .milliseconds(200))  // the new wait's reads at 200…350; the old read at 200 is stale

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.targetResolver.readCount == 9)
        #expect(harness.presenter.wakingApplicationNames.count == 2)
    }
}
