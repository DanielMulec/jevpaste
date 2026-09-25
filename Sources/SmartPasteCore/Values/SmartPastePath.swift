/// Which Smart Paste path a Paste Attempt took after the Pre-checks passed. For diagnostics only.
public enum SmartPastePath: Equatable, Sendable {
    /// Jev was consulted over the Candidates, whatever came of it: a Paste Result (possibly through the
    /// Candidate Chooser), No Suitable Match, a failure, or a cancel. `freeTextProbability` is Jev's judgement
    /// that the Target is a Free-text Target, below the threshold; `nil` when no decision arrived. `offer` is how
    /// the No Suitable Match offer ended, `nil` when none was shown.
    case jev(freeTextProbability: Double? = nil, offer: NoSuitableMatchOfferEnd? = nil)
    /// Jev judged the Target a Free-text Target with `probability` at or above the threshold: the whole Active
    /// Item was pasted as a Direct Paste.
    case freeTextTarget(probability: Double)
    /// A single-line Active Item, inserted whole without Jev.
    case directPaste

    /// How the No Suitable Match offer ended, `nil` when the attempt showed none.
    public var noSuitableMatchOfferEnd: NoSuitableMatchOfferEnd? {
        guard case .jev(_, let offer) = self else { return nil }
        return offer
    }

    /// This path with how the No Suitable Match offer ended; Jev's free-text probability is kept. The offer only
    /// follows a Jev consultation, so any other path is returned unchanged.
    func endingOffer(_ end: NoSuitableMatchOfferEnd) -> SmartPastePath {
        guard case .jev(let freeTextProbability, _) = self else { return self }
        return .jev(freeTextProbability: freeTextProbability, offer: end)
    }
}

/// How the offer to paste the whole Active Item after No Suitable Match ended.
public enum NoSuitableMatchOfferEnd: Equatable, Sendable {
    /// Enter: the whole Active Item was delivered as a Direct Paste.
    case accepted
    /// Esc, click-away or ⌘⇧V: nothing inserted.
    case dismissed
    /// The offer's time limit ran out: nothing inserted.
    case timedOut
}
