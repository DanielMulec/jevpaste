/// Monotonic time and one-shot timers for the Paste Attempt: the 150 ms indicator, the 5 s clock, rate-limit
/// back-off and the 120 ms Restore Window.
///
/// The real adapter lives in the app shell; tests supply a manual clock that advances on command.
@MainActor
public protocol PasteAttemptClock {
    var now: ContinuousClock.Instant { get }
    /// Calls `action` on the main actor once `delay` has passed, unless cancelled first.
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any ScheduledAction
}

/// A pending timer from `PasteAttemptClock`.
@MainActor
public protocol ScheduledAction {
    /// Prevents the action from running; has no effect once it ran.
    func cancel()
}
