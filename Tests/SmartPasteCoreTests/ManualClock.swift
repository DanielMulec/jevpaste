import SmartPasteCore

/// A `PasteAttemptClock` that only moves when a test calls `advance(by:)`, firing due actions in time order.
@MainActor
final class ManualClock: PasteAttemptClock {
    /// Simulates timers whose action was already queued when `cancel()` was called: cancelled timers still fire.
    var ignoresCancellation = false

    private final class Timer: ScheduledAction {
        let fireAt: ContinuousClock.Instant
        let order: Int
        let action: @MainActor () -> Void
        var isCancelled = false

        init(fireAt: ContinuousClock.Instant, order: Int, action: @escaping @MainActor () -> Void) {
            self.fireAt = fireAt
            self.order = order
            self.action = action
        }

        func cancel() {
            isCancelled = true
        }
    }

    private let origin = ContinuousClock.now
    private var timers: [Timer] = []
    private var scheduledCount = 0
    private(set) var now: ContinuousClock.Instant

    init() {
        now = origin
    }

    /// Time passed since the clock was created.
    var elapsed: Duration { now - origin }

    /// Timers that are neither cancelled nor fired.
    var pendingTimerCount: Int { timers.count { !$0.isCancelled } }

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any ScheduledAction {
        scheduledCount += 1
        let timer = Timer(fireAt: now + delay, order: scheduledCount, action: action)
        timers.append(timer)
        return timer
    }

    func advance(by duration: Duration) {
        let target = now + duration
        while let next = nextDueTimer(notAfter: target) {
            timers.removeAll { $0 === next }
            now = next.fireAt
            next.action()
        }
        now = max(now, target)  // an action may have advanced the clock itself (a slow synchronous step)
    }

    private func nextDueTimer(notAfter target: ContinuousClock.Instant) -> Timer? {
        if !ignoresCancellation {
            timers.removeAll { $0.isCancelled }
        }
        return timers.filter { $0.fireAt <= target }.min { ($0.fireAt, $0.order) < ($1.fireAt, $1.order) }
    }
}
