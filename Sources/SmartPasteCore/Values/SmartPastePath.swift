/// Which Smart Paste path a Paste Attempt took after the Pre-checks passed. For diagnostics only.
public enum SmartPastePath: Equatable, Sendable {
    /// Jev was consulted over the Candidates, whatever came of it: a Paste Result (possibly through the
    /// Candidate Chooser), No Suitable Match, a failure, or a cancel. `freeTextProbability` is Jev's judgement
    /// that the Target is a Free-text Target, below the threshold; `nil` when no decision arrived.
    case jev(freeTextProbability: Double? = nil)
    /// Jev judged the Target a Free-text Target with `probability` at or above the threshold: the whole Active
    /// Item was pasted as a Direct Paste.
    case freeTextTarget(probability: Double)
    /// A single-line Active Item, inserted whole without Jev.
    case directPaste
}
