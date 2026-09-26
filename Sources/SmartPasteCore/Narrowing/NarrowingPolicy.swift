/// Everything a later Narrowing round may retune, in one value: the wordings, the option form's ids, the cutting and
/// grouping numbers, the follow-up rule and the size model. Injected through `PasteAttemptRules`; no other code holds
/// a Narrowing number or text. `r2b` is the design the spike proved (issue #49, `spikes/narrowing/round2/FINDINGS.md`).
public struct NarrowingPolicy: Equatable, Sendable {
    public let wordings: NarrowingWordings
    public let optionIDs: NarrowingOptionIDs
    public let sizeModel: NarrowingSizeModel
    /// Fine runs: every run of 1…this many tokens inside one line is offered next to the coarse pieces.
    public let fineRunTokenLimit: Int
    /// Layout "cont": when a step has at most this many coarse pieces, they are repeated in every choice and the
    /// fine runs are spread over the choices; otherwise all pieces go in document order.
    public let repeatedCoarseLimit: Int
    /// Fine runs are left out when a step would need more choice questions than this.
    public let maximumQuestionsPerStep: Int
    /// A piece with at least this probability in any choice of a step is carried into its follow-up choice.
    public let carryThreshold: Double
    /// The follow-up request also asks the next step of this many of the most likely carried pieces.
    public let speculativeWidth: Int

    public static let r2b = NarrowingPolicy(
        wordings: .r2b, optionIDs: .r2b, sizeModel: .r2b, fineRunTokenLimit: 8, repeatedCoarseLimit: 126,
        maximumQuestionsPerStep: 12, carryThreshold: 0.01, speculativeWidth: 3
    )

    /// Pieces per choice: Jev's options per choice minus the unchanged piece, `nothing_fits` and `ask_user`.
    var piecesPerChoice: Int { sizeModel.optionsPerChoice - 3 }
}

/// The ids of a Narrowing request's questions and options: Jev answers with them, Core maps them back.
public struct NarrowingOptionIDs: Equatable, Sendable {
    /// Step 1's option for the whole copy.
    public let everything: String
    /// The unchanged piece at a later step in the full-text form (in the excerpt-id form it is the piece's own id).
    public let keep: String
    public let nothingFits: String
    public let askUser: String
    /// Excerpt ids, shared by the questions of one request: prefix + zero-padded number (`x0000`).
    public let excerptPrefix: String
    public let excerptDigits: Int
    /// Full-text piece options, numbered per question: prefix + zero-padded number (`e000`).
    public let fullTextPrefix: String
    public let fullTextDigits: Int
    /// A step's choices: prefix + number (`narrow_0`).
    public let stepQuestionPrefix: String
    public let followUpQuestion: String
    /// The speculative next steps in a follow-up request: prefix + number (`spec_0`).
    public let speculativeQuestionPrefix: String

    public static let r2b = NarrowingOptionIDs(
        everything: "everything", keep: "keep", nothingFits: "nothing_fits", askUser: "ask_user",
        excerptPrefix: "x", excerptDigits: 4, fullTextPrefix: "e", fullTextDigits: 3, stepQuestionPrefix: "narrow_",
        followUpQuestion: "follow_up", speculativeQuestionPrefix: "spec_"
    )

    func excerptID(_ number: Int) -> String { excerptPrefix + Self.padded(number, to: excerptDigits) }
    func fullTextID(_ number: Int) -> String { fullTextPrefix + Self.padded(number, to: fullTextDigits) }

    private static func padded(_ number: Int, to digits: Int) -> String {
        let text = String(number)
        return String(repeating: "0", count: max(0, digits - text.count)) + text
    }
}
