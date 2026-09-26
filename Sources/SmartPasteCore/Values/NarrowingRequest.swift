/// One Narrowing request to Jev: the whole copy and the Target Context as `state`, and one or more choice questions
/// asked in parallel over it. Core builds every part of it — ids, form and wordings; the `DecisionService` adapter only
/// sends `state` and `questions` as rendered here.
public struct NarrowingRequest: Equatable, Sendable {
    /// The pinned Active Item's full text; document order carries meaning, so it is sent at every step.
    public let sourceDocument: String
    public let targetContext: TargetContext
    /// The excerpt-id form's texts, by id in the order the ids were given; empty in the full-text form.
    public let excerpts: [NarrowingExcerpt]
    public let questions: [ChoiceQuestion]

    public init(
        sourceDocument: String, targetContext: TargetContext, excerpts: [NarrowingExcerpt], questions: [ChoiceQuestion]
    ) {
        self.sourceDocument = sourceDocument
        self.targetContext = targetContext
        self.excerpts = excerpts
        self.questions = questions
    }

    /// `state` as Jev reads it: `source_document`, `target_context` and, in the excerpt-id form, `excerpts`.
    public var stateJSON: OrderedJSON {
        var members = [
            OrderedJSON.Member("source_document", .string(sourceDocument)),
            OrderedJSON.Member("target_context", targetContext.json),
        ]
        if !excerpts.isEmpty {
            members.append(.init("excerpts", .object(excerpts.map { .init($0.id, .string($0.text)) })))
        }
        return .object(members)
    }

    /// `questions` as Jev reads them, in order.
    public var questionsJSON: OrderedJSON {
        .object(questions.map { .init($0.id, $0.json) })
    }
}

/// The text of one excerpt id in the excerpt-id form.
public struct NarrowingExcerpt: Equatable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

/// One choice question: its instructions and its options, in the order Jev reads them.
public struct ChoiceQuestion: Equatable, Sendable {
    public enum Instructions: Equatable, Sendable {
        /// Step 1: the instructions alone.
        case wholeCopy(String)
        /// Later steps: the current piece verbatim beside the question.
        case onPiece(currentPiece: String, question: String)
    }

    public let id: String
    public let instructions: Instructions
    public let options: [ChoiceOption]

    public init(id: String, instructions: Instructions, options: [ChoiceOption]) {
        self.id = id
        self.instructions = instructions
        self.options = options
    }

    var json: OrderedJSON {
        let instructionsJSON: OrderedJSON
        switch instructions {
        case .wholeCopy(let text):
            instructionsJSON = .string(text)
        case .onPiece(let currentPiece, let question):
            instructionsJSON = .object([
                .init("current_piece", .string(currentPiece)), .init("question", .string(question)),
            ])
        }
        return .object([
            .init("type", .string("choice")), .init("instructions", instructionsJSON),
            .init("criteria", .object(options.map { .init($0.id, $0.description.json) })),
        ])
    }
}

/// One option of a choice question.
public struct ChoiceOption: Equatable, Sendable {
    public enum Description: Equatable, Sendable {
        case text(String)
        /// Excerpt-id form: no description, the option id's text is in `excerpts`.
        case excerpt
        /// Full-text form, later steps: the unchanged piece's option names it and carries its text.
        case keptPiece(option: String, text: String)

        var json: OrderedJSON {
            switch self {
            case .text(let text): .string(text)
            case .excerpt: .null
            case .keptPiece(let option, let text):
                .object([.init("option", .string(option)), .init("text", .string(text))])
            }
        }
    }

    public let id: String
    public let description: Description

    public init(id: String, description: Description) {
        self.id = id
        self.description = description
    }
}

extension TargetContext {
    /// `target_context` on the wire, in the spike's key order; absent and empty fields are left out.
    var json: OrderedJSON {
        let texts: [(String, String?)] = [
            ("app_name", appName), ("window_title", windowTitle), ("field_label", fieldLabel),
            ("placeholder", placeholder), ("section_heading", sectionHeading),
        ]
        var members = texts.compactMap { key, value in
            value.flatMap { $0.isEmpty ? nil : OrderedJSON.Member(key, .string($0)) }
        }
        if !siblingFieldLabels.isEmpty {
            members.append(.init("sibling_field_labels", .array(siblingFieldLabels.map(OrderedJSON.string))))
        }
        if !surroundingText.isEmpty {
            members.append(.init("surrounding_text", .string(surroundingText)))
        }
        return .object(members)
    }
}
