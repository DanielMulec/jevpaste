import SmartPasteCore

@testable import JevPasteApp

/// Records what the presenter asks the indicator to display and lets a test click it.
@MainActor
final class RecordingIndicatorSurface: IndicatorSurface {
    /// The content on screen, or `nil` while the indicator is hidden.
    private(set) var displayed: IndicatorContent?
    /// Whether the indicator holds key focus, so Enter and Esc reach it.
    private(set) var holdsKeyFocus = false
    /// Like the AppKit panel: giving up key focus on `display` reports a click-away at once, synchronously.
    var reportsClickAwayWhenGivingUpKeyFocus = false
    private var onClick: (@MainActor () -> Void)?
    private var onOfferEvent: (@MainActor (IndicatorOfferEvent) -> Void)?

    func forwardClicks(to handler: @escaping @MainActor () -> Void) {
        onClick = handler
    }

    func forwardOfferEvents(to handler: @escaping @MainActor (IndicatorOfferEvent) -> Void) {
        onOfferEvent = handler
    }

    func display(_ content: IndicatorContent) {
        let gaveUpKeyFocus = holdsKeyFocus
        displayed = content
        holdsKeyFocus = false
        if gaveUpKeyFocus && reportsClickAwayWhenGivingUpKeyFocus {
            onOfferEvent?(.dismiss(.clickAway))
        }
    }

    func displayTakingKeyFocus(_ content: IndicatorContent) {
        displayed = content
        holdsKeyFocus = true
    }

    func hide() {
        displayed = nil
        holdsKeyFocus = false
    }

    /// Enter, Esc or click-away while the indicator holds key focus.
    func send(_ event: IndicatorOfferEvent) {
        guard holdsKeyFocus else { return }
        onOfferEvent?(event)
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
