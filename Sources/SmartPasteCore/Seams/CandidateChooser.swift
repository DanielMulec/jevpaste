/// The small in-app prompt shown when Jev asks the user during Narrowing: it offers the rows Jev filled it with (one
/// or more excerpts of the Active Item, in the order found) and the user picks one or cancels.
///
/// The real adapter lives in the app shell (non-activating panel); tests supply an in-memory fake.
@MainActor
public protocol CandidateChooser {
    /// Offers `candidates` and calls `reply` once: the chosen Candidate, or `nil` for Esc or click-away.
    /// Before replying with a Candidate, the adapter returns focus to the Bound Target's app.
    func presentChoice(
        among candidates: [Candidate],
        for target: BoundTarget,
        reply: @escaping @MainActor (Candidate?) -> Void
    )
}
