/// Plans the choices of one Narrowing step (the spike's `step_chunks`): the piece's children under the step's size
/// budget, laid out into choices of at most 252 pieces, in the excerpt-id form or — when that would overfill the
/// state — in the full-text form, re-split by the full-text budget.
struct StepPlanner {
    let copy: String
    let context: TargetContext
    let policy: NarrowingPolicy
    /// The estimated tokens of `state` without excerpts: the copy and the Target Context.
    private let stateTokens: Double

    init(copy: String, context: TargetContext, policy: NarrowingPolicy) {
        self.copy = copy
        self.context = context
        self.policy = policy
        let state = NarrowingRequest(sourceDocument: copy, targetContext: context, excerpts: [], questions: [])
        stateTokens = policy.sizeModel.estimatedTokens(of: state.stateJSON.rendered)
    }

    /// The step's children laid out into choices for `form`; `[[]]` when the piece has nothing smaller to offer.
    func choices(on piece: Substring, form: OptionForm) -> [[Substring]] {
        let budget = budget(on: piece)
        return choices(of: children(of: piece, budget: budget), on: piece, form: form, budget)
    }

    /// The request asking one step on `piece`: its choices named `narrow_0`, `narrow_1`, … in the excerpt-id form,
    /// or in the full-text form when the ids would not fit. Both forms offer the same children.
    func stepRequest(on piece: Substring) -> RequestAssembly {
        let budget = budget(on: piece)
        let children = children(of: piece, budget: budget)
        let byExcerptIDs = assembly(
            on: piece, form: .excerptIDs, choices(of: children, on: piece, form: .excerptIDs, budget))
        return byExcerptIDs.fitsJev
            ? byExcerptIDs
            : assembly(on: piece, form: .fullText, choices(of: children, on: piece, form: .fullText, budget))
    }

    /// The piece's children; at step 1 without the copy's text as keeping it pastes it (outer line breaks stripped).
    private func children(of piece: Substring, budget: StepBudget) -> PieceChildren {
        let isFirstStep = piece.utf8.elementsEqual(copy.utf8)
        let pastedWhenKept = isFirstStep ? Substring(OuterLineBreaks.stripped(from: copy)) : nil
        return PieceChildren(of: piece, pastedWhenKept: pastedWhenKept, policy: policy, budget: budget)
    }

    private func choices(
        of children: PieceChildren, on piece: Substring, form: OptionForm, _ budget: StepBudget
    ) -> [[Substring]] {
        layOut(children, on: piece, room: form == .fullText && budget.room > 0 ? budget.room : nil)
    }

    private func assembly(on piece: Substring, form: OptionForm, _ choices: [[Substring]]) -> RequestAssembly {
        var assembly = RequestAssembly(copy: copy, context: context, policy: policy, form: form)
        for (number, pieces) in choices.enumerated() {
            assembly.addChoice(id: policy.optionIDs.stepQuestionPrefix + String(number), on: piece, offering: pieces)
        }
        return assembly
    }

    /// The step's budget: the state once, and per question 250 + 900 tokens plus `current_piece` after step 1.
    private func budget(on piece: Substring) -> StepBudget {
        let sizeModel = policy.sizeModel
        let isFirstStep = piece.utf8.elementsEqual(copy.utf8)
        let pieceTokens = isFirstStep ? 0 : sizeModel.estimatedTokens(of: piece)
        return StepBudget(
            sizeModel: sizeModel, stateTokens: stateTokens,
            questionTokens: sizeModel.tokensPerQuestion + sizeModel.questionAllowance + pieceTokens,
            piecesPerChoice: policy.piecesPerChoice
        )
    }

    /// Layout "cont": few coarse pieces are repeated in every choice and the fine runs spread over the choices in
    /// document order; otherwise every piece in document order. `room`: option tokens per choice (full text only).
    private func layOut(_ children: PieceChildren, on piece: Substring, room: Double?) -> [[Substring]] {
        let perChoice = policy.piecesPerChoice
        let cost = { (piece: Substring) in policy.sizeModel.optionTokens(of: piece) }
        guard !children.fine.isEmpty, children.coarse.count <= policy.repeatedCoarseLimit else {
            return StepBudget.split(documentOrder(children.all, in: piece), size: perChoice, room: room, cost: cost)
        }
        let coarseRoom = room.map { $0 - children.coarse.reduce(0) { $0 + cost($1) } }
        let parts = StepBudget.split(
            documentOrder(children.fine, in: piece), size: perChoice - children.coarse.count, room: coarseRoom,
            cost: cost
        )
        return parts.map { documentOrder(children.coarse + $0, in: piece) }
    }
}
