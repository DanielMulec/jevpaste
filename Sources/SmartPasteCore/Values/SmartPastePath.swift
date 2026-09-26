/// What a Paste Attempt did after the Pre-checks passed: its Narrowing, the requests it sent, and how a No Suitable
/// Match offer ended. For diagnostics only.
public struct SmartPastePath: Equatable, Sendable {
    public var narrowing: NarrowingTrace
    /// Every request sent to Jev, rate-limit retries included.
    public var calls: Int
    /// How the No Suitable Match offer ended, `nil` when the attempt showed none. `accepted` means Enter pasted the
    /// whole Active Item as a Direct Paste.
    public var noSuitableMatchOfferEnd: NoSuitableMatchOfferEnd?

    public init(
        narrowing: NarrowingTrace = NarrowingTrace(), calls: Int = 0,
        noSuitableMatchOfferEnd: NoSuitableMatchOfferEnd? = nil
    ) {
        self.narrowing = narrowing
        self.calls = calls
        self.noSuitableMatchOfferEnd = noSuitableMatchOfferEnd
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
