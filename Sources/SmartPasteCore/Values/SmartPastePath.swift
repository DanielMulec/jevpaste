/// Which of the two Smart Paste paths a Paste Attempt took after the Pre-checks passed.
public enum SmartPastePath: Equatable, Sendable {
    /// Jev chose the Paste Result among the Candidates, possibly through the Candidate Chooser.
    case jev
    /// A single-line Active Item, inserted whole without Jev.
    case directPaste
}
