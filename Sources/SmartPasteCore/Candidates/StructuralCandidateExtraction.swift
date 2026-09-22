/// Derives Candidates from the structure of the Active Item: its lines, the values of its `Label: value` lines,
/// its paragraphs, its heading-led sections and the whole item.
///
/// Pure and deterministic. Rules: `docs/design/candidate-derivation.md`.
public struct StructuralCandidateExtraction: CandidateExtraction {
    public init() {}

    public func candidates(in item: ClipboardItem) -> [Candidate] {
        let lines = item.text.sourceLines
        return (lines.singleLineExcerpts + lines.multiLineExcerpts)
            .inDocumentOrder()
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
