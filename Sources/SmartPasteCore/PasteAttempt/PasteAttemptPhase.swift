/// Where the current Paste Attempt is. `idle` means none is running and ⌘⇧V would start one.
enum PasteAttemptPhase: Equatable {
    case idle
    /// The Wake Wait: the focus is not readable yet and is re-read until it is or the limit passes; no Bound Target.
    case wakeWaiting
    /// A `DecisionService` request is outstanding.
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
    /// What asking Jev needs; `nil` for a Direct Paste, which never asks.
    let jevConsultation: JevConsultation?
    /// How long the Wake Wait before it lasted; `nil` when the focus was readable at ⌘⇧V.
    let wakeWait: Duration?
    /// The Smart Paste path so far: set when the attempt starts, refined when Jev's decision arrives.
    var path: SmartPastePath
}

/// The part of a Paste Attempt that only the Jev path has.
struct JevConsultation {
    /// The Target Context as screened at ⌘⇧V: what every request sends, and the note the outcome carries.
    let contextToSend: ScreenedTargetContext
    let candidates: [Candidate]
    /// When the 5 s clock runs out.
    let deadline: ContinuousClock.Instant
}
