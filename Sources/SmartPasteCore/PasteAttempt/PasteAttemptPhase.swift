/// Where the current Paste Attempt is. `idle` means none is running and ⌘⇧V would start one.
enum PasteAttemptPhase: Equatable {
    case idle
    /// A `DecisionService` request is outstanding.
    case deciding
    /// Jev asked us to wait; a retry is scheduled inside the 5 s clock.
    case waitingToRetry
    /// The Candidate Chooser is open; off the clock.
    case choosing
    /// The uninterruptible delivery step: clipboard swap, ⌘V and the Restore Window.
    case delivering
}

/// What a running Paste Attempt pinned when it started, plus its pending timers.
struct RunningAttempt {
    /// Distinguishes this attempt from earlier ones, so late replies and timers of an ended attempt are ignored.
    let number: Int
    let item: ClipboardItem
    let target: BoundTarget
    let candidates: [Candidate]
    /// When the 5 s clock runs out.
    let deadline: ContinuousClock.Instant
    var timers: [any ScheduledAction] = []
}
