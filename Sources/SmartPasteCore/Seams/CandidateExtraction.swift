/// The local rules that split the Active Item into Candidates and detect same-type ambiguity.
///
/// The rules arrive with the Candidate derivation slice; tests supply stubs.
public protocol CandidateExtraction: Sendable {
    /// Candidates of `item`, each an exact contiguous substring, at most 254 (Jev takes 255 options,
    /// one of them `none_of_these`).
    func candidates(in item: ClipboardItem) -> [Candidate]
    /// The Candidates sharing `chosen`'s detected type (email, URL, phone, …), `chosen` included.
    /// Two or more open the Candidate Chooser.
    func sameTypeAlternatives(to chosen: Candidate, among candidates: [Candidate]) -> [Candidate]
}
