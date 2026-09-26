/// Where the current Paste Attempt is. `idle` means none is running and ⌘⇧V would start one.
enum PasteAttemptPhase: Equatable {
    case idle
    /// The Wake Wait: the focus is not readable yet and is re-read until it is or the limit passes; no Bound Target.
    case wakeWaiting
    /// Narrowing: a `DecisionService` request is outstanding, from the first step to the last.
    case deciding
    /// Jev asked us to wait; a retry is scheduled inside the 5 s clock.
    case waitingToRetry
    /// The Candidate Chooser is open; off the clock.
    case choosing
    /// No Suitable Match, with Enter offered to paste the whole Active Item; off the 5 s clock, on the offer's own.
    case offeringDirectPaste
    /// The uninterruptible delivery step: clipboard swap, ⌘V and the Restore Window.
    case delivering
}

/// What a running Paste Attempt pinned once its Bound Target resolved.
struct RunningAttempt {
    /// Distinguishes this attempt from earlier ones, so late replies and timers of an ended attempt are ignored.
    let number: Int
    let item: ClipboardItem
    let target: BoundTarget
    /// Narrowing and what it needs.
    var consultation: JevConsultation
    /// How long the Wake Wait before it lasted; `nil` when the focus was readable at ⌘⇧V.
    let wakeWait: Duration?
    /// The Smart Paste path so far: refined with every request, every step and the offer's end.
    var path: SmartPastePath
}

/// What consulting Jev needs across the steps of Narrowing.
struct JevConsultation {
    /// The Target Context as screened at ⌘⇧V: what every request sends, and the note the outcome carries.
    let contextToSend: ScreenedTargetContext
    /// When the 5 s clock runs out: it covers every step and every rate-limit wait.
    let deadline: ContinuousClock.Instant
    var narrowing: Narrowing
    /// The request outstanding or waiting to be retried after a rate limit.
    var pendingRequest: NarrowingRequest?
}
