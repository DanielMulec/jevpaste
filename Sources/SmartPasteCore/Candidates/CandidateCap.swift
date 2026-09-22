extension Array where Element == Excerpt {
    /// The most Candidates one Jev request may offer: Jev accepts 255 options, and the JevGateway adapter adds
    /// `none_of_these` as one of them.
    static let candidateCap = 254

    /// These excerpts cut down to `candidateCap`, still in document order.
    ///
    /// Kinds go in `Excerpt.Kind.dropRank` order — the whole item, sections, paragraphs, whole `Label: value`
    /// lines — and within a kind the last one in the document first. Coarse and labelled excerpts go first because
    /// finer excerpts inside them stay offered. If that is not enough, the excerpts at the end of the document go.
    func cappedForJev() -> [Excerpt] {
        var surplus = count - Self.candidateCap
        guard surplus > 0 else { return self }
        var dropped: Set<Int> = []
        for rank in Set(compactMap(\.kind.dropRank)).sorted() where surplus > 0 {
            let dropping = indices.filter { self[$0].kind.dropRank == rank }.suffix(surplus)
            dropped.formUnion(dropping)
            surplus -= dropping.count
        }
        let kept = indices.filter { !dropped.contains($0) }.map { self[$0] }
        return Array(kept.prefix(Self.candidateCap))
    }
}
