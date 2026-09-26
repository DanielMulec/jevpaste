/// Which of the two option forms a Narrowing request uses (design `r2b`, `FINDINGS.md` "Option form").
enum OptionForm: Equatable {
    /// Every piece option is an excerpt id with no description; its text is in `state.excerpts`, once per request.
    case excerptIDs
    /// The fallback when the excerpt ids would overfill the state: every option carries its text.
    case fullText
}

/// What an option id of a planned question stands for.
enum OptionMeaning: Equatable {
    /// The question's current piece, unchanged.
    case unchanged
    case piece(Substring)
    case nothingFits
    case askUser
}

/// A choice question as sent, with what each of its option ids means.
struct PlannedQuestion {
    let question: ChoiceQuestion
    let currentPiece: Substring
    let form: OptionForm
    let meanings: [String: OptionMeaning]

    /// The pieces this question offered, besides the current piece unchanged.
    var offeredPieces: [Substring] {
        meanings.values.compactMap { meaning in
            guard case .piece(let text) = meaning else { return nil }
            return text
        }
    }
}

/// Builds one Narrowing request question by question (the spike's `Request`): excerpt ids shared by its questions and
/// numbered in order of first use, every option id mapped back, and the size estimate of exactly what is sent.
struct RequestAssembly {
    let copy: String
    let context: TargetContext
    let policy: NarrowingPolicy
    let form: OptionForm
    private(set) var questions: [PlannedQuestion] = []
    private var excerpts: [NarrowingExcerpt] = []
    private var excerptIDs: [ExactText: String] = [:]

    init(copy: String, context: TargetContext, policy: NarrowingPolicy, form: OptionForm) {
        self.copy = copy
        self.context = context
        self.policy = policy
        self.form = form
    }

    var request: NarrowingRequest {
        NarrowingRequest(
            sourceDocument: copy, targetContext: context, excerpts: excerpts, questions: questions.map(\.question)
        )
    }

    /// Adds the choice `id`: `piece` unchanged, then `pieces` (in the order given), then `nothing_fits` and `ask_user`.
    mutating func addChoice(id: String, on piece: Substring, offering pieces: [Substring]) {
        let isFirstStep = piece.utf8.elementsEqual(copy.utf8)
        var options = [unchangedOption(for: piece, isFirstStep: isFirstStep)]
        var meanings = [options[0].id: OptionMeaning.unchanged]
        for (index, text) in pieces.enumerated() {
            let option =
                form == .excerptIDs
                ? ChoiceOption(id: excerptID(for: text), description: .excerpt)
                : ChoiceOption(id: policy.optionIDs.fullTextID(index), description: .text(String(text)))
            options.append(option)
            meanings[option.id] = .piece(text)
        }
        let ids = policy.optionIDs
        options += [
            ChoiceOption(id: ids.nothingFits, description: .text(policy.wordings.nothingFits)),
            ChoiceOption(id: ids.askUser, description: .text(policy.wordings.askUser)),
        ]
        meanings[ids.nothingFits] = .nothingFits
        meanings[ids.askUser] = .askUser
        let question = ChoiceQuestion(id: id, instructions: instructions(on: piece, isFirstStep), options: options)
        questions.append(PlannedQuestion(question: question, currentPiece: piece, form: form, meanings: meanings))
    }

    /// Whether the request stays within Jev's limits by the size model: the whole request, and the state plus its
    /// largest question. The state counts once, however many questions share it.
    var fitsJev: Bool {
        let sizeModel = policy.sizeModel
        let state =
            sizeModel.estimatedTokens(of: request.stateJSON.rendered)
            + sizeModel.tokensPerExcerptID * Double(excerpts.count)
        let questionTokens = questions.map { planned in
            sizeModel.tokensPerQuestion + sizeModel.estimatedTokens(of: planned.question.json.rendered)
                + sizeModel.tokensPerOption * Double(planned.question.options.count)
        }
        return state + questionTokens.reduce(0, +) <= sizeModel.requestBudget
            && state + (questionTokens.max() ?? 0) <= sizeModel.questionBudget
    }

    private mutating func unchangedOption(for piece: Substring, isFirstStep: Bool) -> ChoiceOption {
        let ids = policy.optionIDs
        let wordings = policy.wordings
        if isFirstStep { return ChoiceOption(id: ids.everything, description: .text(wordings.everything)) }
        switch form {
        case .excerptIDs:
            return ChoiceOption(id: excerptID(for: piece), description: .text(wordings.keep))
        case .fullText:
            return ChoiceOption(id: ids.keep, description: .keptPiece(option: wordings.keep, text: String(piece)))
        }
    }

    private func instructions(on piece: Substring, _ isFirstStep: Bool) -> ChoiceQuestion.Instructions {
        let wordings = policy.wordings
        if isFirstStep {
            return .wholeCopy(form == .excerptIDs ? wordings.firstStepWithExcerptIDs : wordings.firstStepWithFullText)
        }
        let question = form == .excerptIDs ? wordings.laterStepWithExcerptIDs : wordings.laterStepWithFullText
        return .onPiece(currentPiece: String(piece), question: question)
    }

    /// The excerpt id of `text`, given on first use.
    private mutating func excerptID(for text: Substring) -> String {
        if let known = excerptIDs[ExactText(text)] { return known }
        let id = policy.optionIDs.excerptID(excerpts.count)
        excerptIDs[ExactText(text)] = id
        excerpts.append(NarrowingExcerpt(id: id, text: String(text)))
        return id
    }
}
