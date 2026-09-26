/// Every text Jev reads in a Narrowing request, verbatim from design `r2b`
/// (`spikes/narrowing/round2/FINDINGS.md` "Every wording, verbatim", branch `spike/narrowing` @ ba32886).
///
/// Place-neutral by construction: no field, place or value vocabulary, no app names. A change here is a new spike
/// round's decision, never a quiet edit; `NarrowingReplayTests` pins every character against the spike's requests.
public struct NarrowingWordings: Equatable, Sendable {
    /// Step 1 `instructions`, excerpt-id form.
    public let firstStepWithExcerptIDs: String
    /// Step 1 `instructions`, full-text fallback form.
    public let firstStepWithFullText: String
    /// Later steps: the `question` beside `current_piece`, excerpt-id form.
    public let laterStepWithExcerptIDs: String
    /// Later steps: the `question` beside `current_piece`, full-text fallback form.
    public let laterStepWithFullText: String
    /// Step 1's option for the whole copy, unchanged.
    public let everything: String
    /// Later steps' option for `current_piece`, unchanged.
    public let keep: String
    public let nothingFits: String
    public let askUser: String

    /// The wordings frozen at round 2's Gate A.
    public static let r2b: NarrowingWordings = {
        let preamble =
            "The user copied `source_document` and pressed paste. `target_context` describes the place where the "
            + "text cursor is, and what surrounds that place. "
        let firstOptions = "One option is everything that was copied, as it is. "
        let laterOptions =
            "`current_piece` is an exact excerpt of `source_document`. One option is `current_piece` kept as it is. "
        let firstExcerptIDs =
            "Every other excerpt option is the id of an exact excerpt cut from `source_document`; `excerpts` gives "
            + "the text of each id, character for character. "
        let firstFullText =
            "Every other excerpt option is an exact excerpt cut from `source_document`; its description is that "
            + "excerpt, character for character. "
        let laterExcerptIDs =
            "Every other excerpt option is the id of a smaller exact excerpt cut from `current_piece`; `excerpts` "
            + "gives the text of each id, character for character. "
        let laterFullText =
            "Every other excerpt option is a smaller exact excerpt cut from `current_piece`; its description is that "
            + "excerpt, character for character. "
        let decide = { (whole: String) in
            "Choose what will be pasted at the text cursor. If that place asks for one particular thing, choose the "
                + "option that is exactly that thing, with nothing missing and nothing extra; only if no option is "
                + "exactly that, choose the option that contains all of it with the least extra text. If that place "
                + "does not ask for one particular thing, choose \(whole). If two or more different excerpts are "
                + "each exactly the thing that place asks for and nothing says which one is meant, choose `ask_user` "
                + "instead of one of them."
        }
        let decideFirst = decide("everything that was copied")
        let decideLater = decide("`current_piece` as it is")
        return NarrowingWordings(
            firstStepWithExcerptIDs: preamble + firstOptions + firstExcerptIDs + decideFirst,
            firstStepWithFullText: preamble + firstOptions + firstFullText + decideFirst,
            laterStepWithExcerptIDs: preamble + laterOptions + laterExcerptIDs + decideLater,
            laterStepWithFullText: preamble + laterOptions + laterFullText + decideLater,
            everything: "Everything that was copied, as it is: all of `source_document`, nothing cut away.",
            keep: "`current_piece` as it is, nothing cut away.",
            nothingFits: "That place asks for one particular thing, and no part of `source_document` is that thing.",
            askUser:
                "That place asks for one particular thing, two or more different excerpts of `source_document` are "
                + "each exactly that thing, and nothing says which one is meant; the user has to pick."
        )
    }()
}
