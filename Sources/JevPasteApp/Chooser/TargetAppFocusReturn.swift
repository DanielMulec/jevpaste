import SmartPasteCore

/// Brings an app to the front and reports which app is frontmost; in the app, `NSRunningApplication` and
/// `NSWorkspace`.
@MainActor
protocol ApplicationActivator {
    var frontmostProcessIdentifier: Int32? { get }
    /// Asks the app with this pid to come to the front; `false` when no such app is running.
    func activate(processIdentifier: Int32) -> Bool
}

/// How handing focus back to the Bound Target's app ended.
enum FocusReturnResult: Equatable {
    case frontmost(after: Duration)
    /// The app was not frontmost within the bound; Core's Bound Target re-verification decides what happens next.
    case notFrontmost(after: Duration)
    case appGone
}

/// Hands focus back to the Bound Target's app after the Candidate Chooser took key focus: activates it, then
/// checks at once and every 10 ms whether it is frontmost, for at most 1 s.
@MainActor
final class TargetAppFocusReturn {
    static let pollInterval = Duration.milliseconds(10)
    static let bound = Duration.seconds(1)

    private let activator: any ApplicationActivator
    private let clock: any PasteAttemptClock

    init(activator: any ApplicationActivator, clock: any PasteAttemptClock) {
        self.activator = activator
        self.clock = clock
    }

    /// Calls `completion` once, when the app with `processIdentifier` is frontmost, the bound ran out, or the app
    /// is gone.
    func returnFocus(
        to processIdentifier: Int32, completion: @escaping @MainActor (FocusReturnResult) -> Void
    ) {
        guard activator.activate(processIdentifier: processIdentifier) else { return completion(.appGone) }
        poll(for: processIdentifier, since: clock.now, completion: completion)
    }

    private func poll(
        for processIdentifier: Int32, since start: ContinuousClock.Instant,
        completion: @escaping @MainActor (FocusReturnResult) -> Void
    ) {
        let elapsed = clock.now - start
        if activator.frontmostProcessIdentifier == processIdentifier { return completion(.frontmost(after: elapsed)) }
        if elapsed >= Self.bound { return completion(.notFrontmost(after: elapsed)) }
        // Strong on purpose: the poll keeps this alive until it completes (≤ 1 s), so the reply is always sent even
        // if the owner lets go mid-poll. The clock drops each action once it fired, so nothing outlives the bound.
        _ = clock.schedule(after: Self.pollInterval) {
            self.poll(for: processIdentifier, since: start, completion: completion)
        }
    }
}
