/// The small in-app prompt shown when several same-type Candidates are plausible for the Target.
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
