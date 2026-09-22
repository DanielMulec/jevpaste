import SmartPasteCore

@testable import JevPasteApp

/// Records what the presenter asks the indicator to display and lets a test click it.
@MainActor
final class RecordingIndicatorSurface: IndicatorSurface {
    /// The content on screen, or `nil` while the indicator is hidden.
    private(set) var displayed: IndicatorContent?
    private var onClick: (@MainActor () -> Void)?

    func forwardClicks(to handler: @escaping @MainActor () -> Void) {
        onClick = handler
    }

    func display(_ content: IndicatorContent) {
        displayed = content
    }

    func hide() {
        displayed = nil
    }

    func click() {
        onClick?()
    }
}

/// A `PasteAttemptClock` that moves only when a test steps it; due actions run in the order they fall due.
@MainActor
final class SteppedClock: PasteAttemptClock {
    private final class Pending: ScheduledAction {
        let dueAt: ContinuousClock.Instant
        let action: @MainActor () -> Void
        var isCancelled = false

        init(dueAt: ContinuousClock.Instant, action: @escaping @MainActor () -> Void) {
            self.dueAt = dueAt
            self.action = action
        }

        func cancel() {
            isCancelled = true
        }
    }

    private(set) var now = ContinuousClock.now
    private var pending: [Pending] = []

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any ScheduledAction {
        let entry = Pending(dueAt: now + delay, action: action)
        pending.append(entry)
        return entry
    }

    func step(by duration: Duration) {
        now += duration
        let due = pending.filter { $0.dueAt <= now && !$0.isCancelled }.sorted { $0.dueAt < $1.dueAt }
        pending.removeAll { $0.dueAt <= now || $0.isCancelled }
        for entry in due where !entry.isCancelled {
            entry.action()
        }
    }
}
