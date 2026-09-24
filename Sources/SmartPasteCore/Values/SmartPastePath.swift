/// Which of the two Smart Paste paths a Paste Attempt took after the Pre-checks passed.
public enum SmartPastePath: Equatable, Sendable {
    /// Jev was consulted over the Candidates, whatever came of it: a Paste Result (possibly through the
    /// Candidate Chooser), No Suitable Match, a failure, or a cancel.
    case jev
    /// A single-line Active Item, inserted whole without Jev.
    case directPaste
}
