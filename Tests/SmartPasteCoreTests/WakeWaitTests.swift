import SmartPasteCore
import Testing

/// The Wake Wait: while the focused element cannot be read, the attempt re-reads it every 50 ms for up to 3 s, then
/// continues exactly as if it had been readable at ⌘⇧V — the 5 s Jev clock starts only then.
@MainActor
struct WakeWaitTests {
    @Test func focusReadableAtOnceStartsNoWakeWait() {
        let harness = PasteAttemptHarness()

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(150))
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.wakingShownAt == nil)
        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.presenter.wakeWaits == [nil])
    }

    @Test func focusReadableOnTheSecondReadAsksJevThen() {
        let harness = PasteAttemptHarness(unreadableReads: 1)

        harness.hotkey.press()
        #expect(harness.jev.requests.isEmpty)
        harness.clock.advance(by: .milliseconds(49))
        #expect(harness.jev.requests.isEmpty)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.jev.requests.first?.sourceDocument == PasteAttemptHarness.sourceText)
    }

    /// Slow synchronous work after the resolution (here the screening) does not extend the clock either.
    @Test(arguments: [Duration.zero, .seconds(1)])
    func theJevClockStartsWhenTheTargetResolves(screeningTakes: Duration) {
        let harness = PasteAttemptHarness(unreadableReads: 1, screeningTakes: screeningTakes)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(50))
        #expect(harness.clock.elapsed == .milliseconds(50) + screeningTakes)
        harness.clock.advance(by: .milliseconds(4_999) - screeningTakes)
        #expect(harness.presenter.outcomes.isEmpty)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.presenter.outcomes == [.failed(.timedOut)])
        #expect(harness.presenter.wakeWaits == [.milliseconds(50)])
    }

    @Test func focusNeverReadableRefusesAtTheLimitWithoutAskingJev() {
        let harness = PasteAttemptHarness(unreadableReads: .max)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(2_999))
        #expect(harness.presenter.outcomes.isEmpty)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.presenter.outcomes == [.refused(.targetNotReady(applicationName: "ChatGPT"))])
        #expect(harness.presenter.wakeWaits == [.seconds(3)])
        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps.isEmpty)
        #expect(harness.clock.pendingTimerCount == 0)
    }

    @Test func cancellingOnTheWakingIndicatorEndsTheAttemptWithNothingPasted() {
        let harness = PasteAttemptHarness(unreadableReads: 10)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        harness.presenter.clickIndicator()
        harness.clock.advance(by: .seconds(6))

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.presenter.wakeWaits == [.milliseconds(150)])
        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }

    @Test func theWakingIndicatorNamesTheAppAfter150Milliseconds() {
        let harness = PasteAttemptHarness(unreadableReads: .max)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(149))
        #expect(harness.presenter.wakingShownAt == nil)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.presenter.wakingShownAt == .milliseconds(150))
        #expect(harness.presenter.wakingApplicationNames == ["ChatGPT"])
        #expect(harness.presenter.processingShownAt == nil)
    }

    @Test func aTargetResolvedAfterTheWakingIndicatorShowsProcessingAtOnce() {
        let harness = PasteAttemptHarness(unreadableReads: 4)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(200))

        #expect(harness.presenter.processingShownAt == .milliseconds(200))
        #expect(harness.jev.requests.count == 1)
    }

    @Test func aTargetResolvedBeforeTheIndicatorShowsNoWakingAndProcessing150MillisecondsLater() {
        let harness = PasteAttemptHarness(unreadableReads: 1)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(199))
        #expect(harness.presenter.processingShownAt == nil)
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.presenter.wakingShownAt == nil)
        #expect(harness.presenter.processingShownAt == .milliseconds(200))
    }

    @Test func preChecksStillRefuseAfterAWakeWait() {
        let harness = PasteAttemptHarness(focusedTarget: PasteAttemptStartTests.passwordField, unreadableReads: 2)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(100))

        #expect(harness.presenter.outcomes == [.refused(.secureField)])
        #expect(harness.presenter.wakeWaits == [.milliseconds(100)])
        #expect(harness.jev.requests.isEmpty)
    }

    @Test func aSingleLineItemIsNarrowedAfterAWakeWaitLikeAnyOther() {
        let harness = PasteAttemptHarness(unreadableReads: 1, sourceText: "ada@example.com")

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(50))
        harness.jev.keep()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.presenter.wakeWaits == [.milliseconds(50)])
        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke, .restore])
        #expect(harness.jev.requests.count == 1)
    }

    @Test func aFocusThatTurnsReadableButNotEditableIsNoEditableTarget() {
        let harness = PasteAttemptHarness(focusedTarget: nil, unreadableReads: 2)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(100))

        #expect(harness.presenter.outcomes == [.refused(.noEditableTarget)])
        #expect(harness.presenter.wakeWaits == [.milliseconds(100)])
    }

    @Test func theJevPathOutcomeCarriesTheWaitedDuration() {
        let harness = PasteAttemptHarness(unreadableReads: 2)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(100))
        harness.jev.narrow(to: "ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.presenter.wakeWaits == [.milliseconds(100)])
    }

    @Test func hotkeyDuringTheWakeWaitIsIgnored() {
        let harness = PasteAttemptHarness(unreadableReads: 1)

        harness.hotkey.press()
        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(50))

        #expect(harness.jev.requests.count == 1)
        #expect(harness.targetResolver.readCount == 2)
    }
}
