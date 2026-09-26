/// What a Paste Attempt does next in Narrowing.
enum NarrowingAction: Equatable {
    /// Ask Jev this request.
    case send(NarrowingRequest)
    /// Jev kept a piece unchanged: deliver this Paste Result (the whole copy with its outer line breaks stripped).
    case pasteResult(String)
    /// Jev chose "nothing fits": No Suitable Match, with the Enter offer.
    case nothingFits
    /// Jev asked the user and filled the Candidate Chooser: these rows, in the order Jev found them.
    case askUser([Candidate])
    /// Jev's pick was not an offered piece, or not a verbatim excerpt inside the current piece.
    case invalidPick
    /// The copy holds no visible character: nothing to paste, no call.
    case nothingToPaste
}

/// Narrowing as a pure value: from the whole Active Item, one step after another, each step one request with one or
/// several choices (and a follow-up choice when several picked different pieces), until Jev keeps a piece unchanged,
/// finds nothing fits, or asks the user — then Jev fills the Candidate Chooser (`ChooserFill`). Every pick is checked
/// byte for byte before it is used.
struct Narrowing {
    private let copy: String
    private let item: ClipboardItem
    private let policy: NarrowingPolicy
    private let planner: StepPlanner
    private var piece: Substring
    private var pending: [PlannedQuestion] = []
    /// The follow-up's speculative next-step questions, by their piece, still waiting for the follow-up's answer.
    private var speculating: [PlannedQuestion] = []
    /// Speculative next steps already answered, by piece.
    private var answeredAhead: [ExactText: AnsweredChoice] = [:]
    /// The Candidate Chooser's fill, once Jev asked the user.
    private var fill: ChooserFill?
    private(set) var trace = NarrowingTrace()

    init(item: ClipboardItem, context: TargetContext, policy: NarrowingPolicy) {
        self.item = item
        copy = item.text
        self.policy = policy
        planner = StepPlanner(copy: copy, context: context, policy: policy)
        piece = copy[...]
    }

    mutating func start() -> NarrowingAction {
        guard copy.contains(where: { !$0.isWhitespace }) else { return .nothingToPaste }
        return step()
    }

    /// Jev's answers to the request `send` last asked for.
    mutating func receive(_ answers: [String: ChoiceAnswer]) -> NarrowingAction {
        if fill != nil { return receiveFill(answers) }
        let questions = pending
        let speculative = speculating
        pending = []
        speculating = []
        var answered: [AnsweredChoice] = []
        for planned in questions {
            guard let answer = answers[planned.question.id] else { return .invalidPick }
            answered.append(AnsweredChoice(planned: planned, answer: answer))
        }
        for planned in speculative {
            if let answer = answers[planned.question.id] {
                answeredAhead[ExactText(planned.currentPiece)] = AnsweredChoice(planned: planned, answer: answer)
            }
        }
        let step = ChoicesOfOneStep(answered: answered)
        guard let first = answered.first else { return .invalidPick }
        guard answered.count > 1, step.agreedAnswer == nil else { return decide(step.agreedAnswer ?? first) }
        return followUp(after: step)
    }

    /// One step on the current piece: answered ahead, final without a call, or a request.
    private mutating func step() -> NarrowingAction {
        if let ahead = answeredAhead.removeValue(forKey: ExactText(piece)) {
            trace.steps.append(.init(questions: 0, followUpSpeculativeQuestions: nil, isSpeculative: true))
            return decide(ahead)
        }
        let isFirstStep = piece.utf8.elementsEqual(copy.utf8)
        let assembly = planner.stepRequest(on: piece)
        guard isFirstStep || assembly.questions.contains(where: { !$0.offeredPieces.isEmpty }) else {
            return .pasteResult(String(piece))
        }
        trace.steps.append(
            .init(questions: assembly.questions.count, followUpSpeculativeQuestions: nil, isSpeculative: false))
        return send(assembly, speculating: 0)
    }

    private mutating func send(_ assembly: RequestAssembly, speculating count: Int) -> NarrowingAction {
        let questions = assembly.questions
        pending = Array(questions.prefix(questions.count - count))
        speculating = Array(questions.suffix(count))
        if assembly.form == .fullText { trace.fullTextRequests += 1 }
        return .send(assembly.request)
    }

    /// One follow-up choice over the carried pieces, carrying the next step of the most likely ones.
    private mutating func followUp(after step: ChoicesOfOneStep) -> NarrowingAction {
        let carried = step.carriedPieces(threshold: policy.carryThreshold).prefix(policy.piecesPerChoice)
        let options = documentOrder(carried.map(\.piece), in: piece)
        let ahead = carried.prefix(policy.speculativeWidth).compactMap { candidate -> (Substring, [Substring])? in
            let choices = planner.choices(on: candidate.piece, form: .excerptIDs)
            guard choices.count == 1, let children = choices.first, !children.isEmpty else { return nil }
            return (candidate.piece, children)
        }
        let attempts: [(OptionForm, Bool)] = [
            (.excerptIDs, true), (.fullText, true), (.excerptIDs, false), (.fullText, false),
        ]
        var assembly = RequestAssembly(copy: copy, context: planner.context, policy: policy, form: .fullText)
        var aheadCount = 0
        for (form, withAhead) in attempts {
            assembly = RequestAssembly(copy: copy, context: planner.context, policy: policy, form: form)
            assembly.addChoice(id: policy.optionIDs.followUpQuestion, on: piece, offering: options)
            aheadCount = withAhead ? ahead.count : 0
            for (number, (aheadPiece, children)) in ahead.prefix(aheadCount).enumerated() {
                let id = policy.optionIDs.speculativeQuestionPrefix + String(number)
                assembly.addChoice(id: id, on: aheadPiece, offering: children)
            }
            if assembly.fitsJev { break }
        }
        trace.markFollowUp(speculativeQuestions: aheadCount)
        return send(assembly, speculating: aheadCount)
    }

    /// The deciding choice's pick, checked byte for byte, turned into the next action.
    private mutating func decide(_ choice: AnsweredChoice) -> NarrowingAction {
        guard let chosen = choice.chosen else { return .invalidPick }
        trace.markChosen(probability: choice.chosenProbability)
        switch chosen {
        case .unchanged:
            return .pasteResult(pasteResult(keeping: choice.planned.currentPiece))
        case .nothingFits:
            return .nothingFits
        case .askUser:
            fill = ChooserFill(deciding: choice.planned)
            trace.chooserFill = ChooserFillTrace()
            return askFill()
        case .piece(let text):
            guard isVerbatimPick(text, of: choice.planned) else { return .invalidPick }
            piece = text
            return step()
        }
    }

    /// What keeping `current` pastes: the piece, or the whole copy with its outer line breaks stripped.
    private func pasteResult(keeping current: Substring) -> String {
        current.utf8.elementsEqual(copy.utf8) ? OuterLineBreaks.stripped(from: copy) : String(current)
    }

    /// Whether `text` is a piece `planned` offered, verbatim in the Active Item and strictly inside its current piece.
    private func isVerbatimPick(_ text: Substring, of planned: PlannedQuestion) -> Bool {
        let offered = planned.offeredPieces.map { Candidate(text: String($0)) }
        let current = planned.currentPiece
        return item.acceptsPasteResult(Candidate(text: String(text)), offeredAmong: offered)
            && current.utf8.count > text.utf8.count && current.containsExactly(text)
    }

    /// Sends the next fill choice.
    private mutating func askFill() -> NarrowingAction {
        guard let fill else { return .invalidPick }
        let (question, excerpts) = fill.nextQuestion(wordings: policy.wordings)
        pending = [question]
        trace.chooserFill?.calls += 1
        if question.form == .fullText { trace.fullTextRequests += 1 }
        return .send(
            NarrowingRequest(
                sourceDocument: copy, targetContext: planner.context, excerpts: excerpts,
                questions: [question.question]))
    }

    /// A fill choice's answer: the next row, or the end of the fill — the chooser with the rows found, or, before
    /// the first row, what keeping the piece or finding nothing fits means at a step.
    private mutating func receiveFill(_ answers: [String: ChoiceAnswer]) -> NarrowingAction {
        guard let planned = pending.first, let answer = answers[planned.question.id] else { return .invalidPick }
        pending = []
        switch AnsweredChoice(planned: planned, answer: answer).chosen {
        case .piece(let text):
            guard isVerbatimPick(text, of: planned) else { return .invalidPick }
            fill?.add(row: text)
            return askFill()
        case .unchanged:
            let rows = stopFilling(because: .keep)
            return rows.isEmpty ? .pasteResult(pasteResult(keeping: planned.currentPiece)) : .askUser(rows)
        case .nothingFits:
            let rows = stopFilling(because: .nothingFits)
            return rows.isEmpty ? .nothingFits : .askUser(rows)
        case .askUser, nil:
            return .invalidPick
        }
    }

    /// Ends the Candidate Chooser's fill for `end` and gives the rows Jev found, in order; empty when there are none
    /// or no fill is running. The coordinator calls it when the clock runs out or the Gateway fails mid-fill.
    mutating func stopFilling(because end: ChooserFillEnd) -> [Candidate] {
        guard let rows = fill?.rows else { return [] }
        fill = nil
        pending = []
        trace.chooserFill?.end = end
        return rows.map { Candidate(text: String($0)) }
    }
}
