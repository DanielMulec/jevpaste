import SmartPasteCore

/// The JSON body of one `POST /v1/evaluate`: the source document and Target Context as `state`, and the two
/// batched questions — which Candidate (or none of these) and whether the document holds a value at all.
///
/// Wording follows `spikes/abstention/run.py` on `spike/jev-contract`, with `target_field` renamed
/// `target_context`.
struct EvaluateRequestBody: Encodable {
    static let model = "typesafe-ai/jev"
    static let choiceQuestionID = "paste"
    static let gateQuestionID = "contains_value"
    static let noneOfTheseOptionID = "none_of_these"
    /// Jev rejects a choice question with more than 255 options; `none_of_these` takes one of them.
    static let maximumCandidateCount = 254
    static let maximumOptionDescriptionLength = 255

    let model = Self.model
    let state: EvaluateState
    let questions: [String: EvaluateQuestion]

    init(_ request: DecisionRequest) {
        state = EvaluateState(
            sourceDocument: request.sourceDocument,
            targetContext: EncodedTargetContext(request.targetContext)
        )
        questions = [
            Self.choiceQuestionID: .choice(among: request.candidates),
            Self.gateQuestionID: .containsValueGate,
        ]
    }

    /// The option id Jev answers with for the Candidate at `index`: `c000` … `c253`.
    static func optionID(forCandidateAt index: Int) -> String {
        let digits = String(index)
        return "c" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }
}

struct EvaluateState: Encodable {
    let sourceDocument: String
    let targetContext: EncodedTargetContext

    enum CodingKeys: String, CodingKey {
        case sourceDocument = "source_document"
        case targetContext = "target_context"
    }
}

/// `TargetContext` on the wire. Absent and empty fields are left out, so Jev never sees placeholder noise.
struct EncodedTargetContext: Encodable {
    let fieldLabel: String?
    let placeholder: String?
    let sectionHeading: String?
    let siblingFieldLabels: [String]?
    let surroundingText: String?

    enum CodingKeys: String, CodingKey {
        case fieldLabel = "field_label"
        case placeholder
        case sectionHeading = "section_heading"
        case siblingFieldLabels = "sibling_field_labels"
        case surroundingText = "surrounding_text"
    }

    init(_ context: TargetContext) {
        fieldLabel = Self.nonEmpty(context.fieldLabel)
        placeholder = Self.nonEmpty(context.placeholder)
        sectionHeading = Self.nonEmpty(context.sectionHeading)
        siblingFieldLabels = context.siblingFieldLabels.isEmpty ? nil : context.siblingFieldLabels
        surroundingText = Self.nonEmpty(context.surroundingText)
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}

struct EvaluateQuestion: Encodable {
    let type: String
    let instructions: String
    let criteria: [String: String]

    static func choice(among candidates: [Candidate]) -> EvaluateQuestion {
        var criteria = [EvaluateRequestBody.noneOfTheseOptionID: noneOfTheseDescription]
        for (index, candidate) in candidates.enumerated() {
            criteria[EvaluateRequestBody.optionID(forCandidateAt: index)] = optionDescription(of: candidate)
        }
        return EvaluateQuestion(type: "choice", instructions: choiceInstructions, criteria: criteria)
    }

    static let containsValueGate = EvaluateQuestion(
        type: "boolean",
        instructions: """
            Does `source_document` contain some exact contiguous excerpt that is the value belonging in \
            `target_context`? Answer true only if such an excerpt exists and could be inserted verbatim into \
            the field.
            """,
        criteria: [
            "true": "An exact excerpt of the document is the value for this field.",
            "false": "No excerpt of the document is the value for this field.",
        ]
    )

    private static let choiceInstructions = """
        The user copied `source_document` and is pasting into `target_context`. Every option is an exact \
        contiguous excerpt of `source_document`. Choose the single excerpt that is exactly the value belonging \
        in that field, as the user would type it. Do not choose an excerpt that is merely related to the field.
        """

    private static let noneOfTheseDescription = """
        None of the listed excerpts is the value that belongs in the target field. Choose this when the source \
        document does not contain the value, or when no single excerpt is right.
        """

    /// The Candidate on one line, cut to Jev's option limit. Only the option id maps back to the Candidate.
    private static func optionDescription(of candidate: Candidate) -> String {
        let oneLine = candidate.text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return String(oneLine.prefix(EvaluateRequestBody.maximumOptionDescriptionLength))
    }
}
