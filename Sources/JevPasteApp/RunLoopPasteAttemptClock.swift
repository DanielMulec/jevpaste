import Foundation
import SmartPasteCore

/// The production `PasteAttemptClock`: monotonic time from `ContinuousClock` and one-shot `Timer`s on the main run
/// loop in common modes, so the 150 ms indicator, the 5 s clock and the Restore Window keep running while a menu
/// or panel tracks events.
@MainActor
final class RunLoopPasteAttemptClock: PasteAttemptClock {
    var now: ContinuousClock.Instant { ContinuousClock.now }

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any ScheduledAction {
        let timer = Timer(timeInterval: delay.timeInterval, repeats: false) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return ScheduledTimer(timer: timer)
    }
}

/// A pending one-shot `Timer`; cancelling invalidates it.
@MainActor
private final class ScheduledTimer: ScheduledAction {
    private let timer: Timer

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer.invalidate()
    }
}
