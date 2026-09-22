/// Where a Paste Attempt is, from ⌘⇧V to its visible outcome.
///
/// Stub for the scaffold: the cases name the outcomes from the domain glossary; transitions arrive with
/// the Paste Attempt state machine.
public enum PasteAttemptState: Equatable, Sendable {
    /// No Paste Attempt is running; a ⌘⇧V would start one.
    case idle
    /// A Paste Attempt is running; a repeated ⌘⇧V is ignored.
    case inProgress
    /// The Paste Result was inserted into the Bound Target.
    case inserted
    /// No Candidate belongs in the Target; nothing was inserted.
    case noSuitableMatch
    /// A Pre-check refused the attempt before anything left the machine.
    case refused
    /// The user cancelled the attempt on our UI.
    case cancelled
    /// The attempt failed (for example the decision timed out or the Bound Target changed).
    case failed

    /// Whether this state is a visible outcome that ends the Paste Attempt.
    public var isFinished: Bool {
        switch self {
        case .idle, .inProgress:
            false
        case .inserted, .noSuitableMatch, .refused, .cancelled, .failed:
            true
        }
    }
}
