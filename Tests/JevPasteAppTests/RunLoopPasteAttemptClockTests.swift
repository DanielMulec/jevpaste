import Foundation
import Testing

@testable import JevPasteApp

@MainActor
struct RunLoopPasteAttemptClockTests {
    private let clock = RunLoopPasteAttemptClock()

    @Test func scheduledActionRunsOnceAfterItsDelay() {
        var runs = 0
        let start = clock.now
        var ranAfter: Duration?
        _ = clock.schedule(after: .milliseconds(30)) {
            runs += 1
            ranAfter = clock.now - start
        }

        spinMainRunLoop(for: .milliseconds(200))

        #expect(runs == 1)
        #expect((ranAfter ?? .zero) >= .milliseconds(30))
    }

    @Test func scheduledActionDoesNotRunBeforeTheRunLoopTurns() {
        var runs = 0
        _ = clock.schedule(after: .zero) { runs += 1 }

        #expect(runs == 0)
    }

    @Test func cancelledActionNeverRunsWhileALaterOneDoes() {
        var cancelledRuns = 0
        var laterRuns = 0
        let cancelled = clock.schedule(after: .milliseconds(10)) { cancelledRuns += 1 }
        _ = clock.schedule(after: .milliseconds(50)) { laterRuns += 1 }

        cancelled.cancel()
        spinMainRunLoop(for: .milliseconds(200))

        #expect(cancelledRuns == 0)
        #expect(laterRuns == 1)
    }

    @Test func cancellingAfterTheActionRanHasNoEffect() {
        var runs = 0
        let scheduled = clock.schedule(after: .milliseconds(10)) { runs += 1 }
        spinMainRunLoop(for: .milliseconds(100))

        scheduled.cancel()

        #expect(runs == 1)
    }

    /// Lets the main run loop process timers for `duration`, as it does between events in the running app.
    private func spinMainRunLoop(for duration: Duration) {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }
}
