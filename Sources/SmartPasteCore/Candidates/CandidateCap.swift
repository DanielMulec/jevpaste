extension Array where Element == Excerpt {
    /// The most Candidates one Jev request may offer: Jev accepts 255 options, and the JevGateway adapter adds
    /// `none_of_these` as one of them.
    static let candidateCap = 254

    /// These excerpts cut down to `candidateCap`, still in document order.
    ///
    /// Whole `Label: value` lines go first, the last ones first, because their value stays offered and is what a
    /// field wants. If that is not enough, the excerpts at the end of the document go.
    func cappedForJev() -> [Excerpt] {
        let surplus = count - Self.candidateCap
        guard surplus > 0 else { return self }
        let droppedWholeLines = Set(indices.filter { self[$0].origin == .wholeLabelledLine }.suffix(surplus))
        let kept = indices.filter { !droppedWholeLines.contains($0) }.map { self[$0] }
        return Array(kept.prefix(Self.candidateCap))
    }
}
