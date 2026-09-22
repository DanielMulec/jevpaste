/// Derives Candidates from the lines of the Active Item and from the values of its `Label: value` lines.
///
/// Pure and deterministic. Rules: `docs/design/candidate-derivation.md`.
public struct LineAndLabelCandidateExtraction: CandidateExtraction {
    public init() {}

    public func candidates(in item: ClipboardItem) -> [Candidate] {
        item.text.trimmedNonBlankLines
            .flatMap(Excerpt.excerpts(ofLine:))
            .removingRepeatedText()
            .cappedForJev()
            .map { Candidate(text: String($0.text)) }
    }

    public func sameTypeAlternatives(to chosen: Candidate, among candidates: [Candidate]) -> [Candidate] {
        let chosenBytes = Array(chosen.text.utf8)
        guard candidates.contains(where: { $0.text.utf8.elementsEqual(chosenBytes) }),
            let chosenType = CandidateType(of: chosen.text)
        else { return [chosen] }
        return candidates.filter { CandidateType(of: $0.text) == chosenType }
    }
}

/// One would-be Candidate: a slice of the Active Item plus where it came from.
struct Excerpt {
    enum Origin {
        /// A line that is not a `Label: value` line.
        case plainLine
        /// The whole of a `Label: value` line; its value is a separate excerpt.
        case wholeLabelledLine
        /// The value of a `Label: value` line.
        case labelValue
    }

    let text: Substring
    let origin: Origin

    /// The excerpts of one trimmed line, in document order: the line, then its value when it is labelled.
    static func excerpts(ofLine line: Substring) -> [Excerpt] {
        guard let value = line.labelledValue else { return [Excerpt(text: line, origin: .plainLine)] }
        return [Excerpt(text: line, origin: .wholeLabelledLine), Excerpt(text: value, origin: .labelValue)]
    }
}

extension Array where Element == Excerpt {
    /// These excerpts without any whose UTF-8 bytes equal an earlier one's. Byte comparison, not `String`
    /// equality, so canonically equivalent but differently encoded texts both stay.
    func removingRepeatedText() -> [Excerpt] {
        var seen: Set<[UInt8]> = []
        return filter { seen.insert([UInt8]($0.text.utf8)).inserted }
    }
}
