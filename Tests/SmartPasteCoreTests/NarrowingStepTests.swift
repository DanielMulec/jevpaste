import Testing

@testable import SmartPasteCore

/// Narrowing as a pure value on a step of several choices (the spike's cell R05: three choices at step 1): when the
/// choices agree, when a follow-up choice is asked, what it carries, and a speculative next step used without a call.
struct NarrowingStepTests {
    private static let cell = NarrowingCell.named("R05_about")

    /// Narrowing on R05 after `start()`, with its first request.
    private static func started() throws -> (narrowing: Narrowing, request: NarrowingRequest) {
        let cell = try #require(cell)
        var narrowing = Narrowing(item: ClipboardItem(text: cell.item), context: cell.targetContext, policy: .r2b)
        guard case .send(let request) = narrowing.start() else { throw StepError.noRequest }
        try #require(request.questions.count == 3)
        return (narrowing, request)
    }

    @Test func whenEveryChoiceKeepsTheWholeCopyThatIsTheAnswerWithoutAFollowUp() throws {
        var (narrowing, request) = try Self.started()

        let action = narrowing.receive(request.answers { question in [(question.options[0].id, 0.9)] })

        let cell = try #require(Self.cell)
        #expect(action == .pasteResult(OuterLineBreaks.stripped(from: cell.item)))
        #expect(narrowing.trace.steps.map(\.followUpSpeculativeQuestions) == [nil])
    }

    @Test func whenEveryChoiceFindsNothingFitsThatIsTheAnswer() throws {
        var (narrowing, request) = try Self.started()

        let action = narrowing.receive(request.answers { _ in [("nothing_fits", 0.8)] })

        #expect(action == .nothingFits)
    }

    @Test func choicesPickingDifferentFixedOptionsNeedAFollowUp() throws {
        var (narrowing, request) = try Self.started()

        let action = narrowing.receive(
            request.answers { question in
                [(question.id == "narrow_0" ? "nothing_fits" : question.options[0].id, 0.7)]
            })

        guard case .send(let followUp) = action else { throw StepError.noRequest }
        #expect(followUp.questions.map(\.id) == ["follow_up"])
    }

    @Test func aFollowUpCarriesEveryPieceWithAtLeastOnePercentInDocumentOrderAndSpeculatesOnTheTopThree() throws {
        var (narrowing, request) = try Self.started()
        let picks = request.questions.map { $0.pieceOptions(in: request).last?.text ?? "" }
        let shared = request.questions[0].pieceOptions(in: request).prefix(2).map(\.text)

        let action = narrowing.receive(
            request.answers { question in
                let pick = question.optionID(of: picks[Int(question.id.dropFirst(7)) ?? 0], in: request) ?? ""
                let carried = question.optionID(of: shared[0], in: request) ?? ""
                let dropped = question.optionID(of: shared[1], in: request) ?? ""
                return [(pick, 0.6), (carried, 0.01), (dropped, 0.009)]
            })

        guard case .send(let followUp) = action else { throw StepError.noRequest }
        let question = try #require(followUp.questions.first)
        let offered = question.pieceOptions(in: followUp).map(\.text)
        let cell = try #require(Self.cell)
        #expect(Set(offered) == Set(picks + [shared[0]]))
        #expect(offered == documentOrder(offered.map { $0[...] }, in: cell.item[...]).map(String.init))
        #expect(question.options.map(\.id).first == "everything")
        #expect(question.options.suffix(2).map(\.id) == ["nothing_fits", "ask_user"])
        #expect(followUp.questions.dropFirst().map(\.id) == ["spec_0", "spec_1", "spec_2"])
        #expect(followUp.questions.dropFirst().map(\.currentPiece) == picks)
        #expect(narrowing.trace.steps.map(\.followUpSpeculativeQuestions) == [3])
    }

    @Test func aFollowUpPickOfASpeculatedPieceIsDecidedByItsSpeculativeAnswerWithoutACall() throws {
        var (narrowing, request) = try Self.started()
        let picks = request.questions.map { $0.pieceOptions(in: request).last?.text ?? "" }
        guard
            case .send(let followUp) = narrowing.receive(
                request.answers { question in
                    [(question.optionID(of: picks[Int(question.id.dropFirst(7)) ?? 0], in: request) ?? "", 0.6)]
                })
        else { throw StepError.noRequest }

        let action = narrowing.receive(
            followUp.answers { question in
                question.id == "follow_up"
                    ? [(question.optionID(of: picks[1], in: followUp) ?? "", 0.8)]
                    : [(question.options[0].id, 0.95)]
            })

        #expect(action == .pasteResult(picks[1]))
        #expect(narrowing.trace.steps.map(\.isSpeculative) == [false, true])
        #expect(narrowing.trace.decidingProbability == 0.95)
    }

    private enum StepError: Error { case noRequest }
}

extension NarrowingRequest {
    /// Jev's answers: for each question, the chosen option id first, then other weighted option ids.
    func answers(_ weighting: (ChoiceQuestion) -> [(id: String, probability: Double)]) -> [String: ChoiceAnswer] {
        Dictionary(
            uniqueKeysWithValues: questions.map { question in
                let weights = weighting(question)
                let probabilities = weights.map { OptionProbability(optionID: $0.id, probability: $0.probability) }
                return (question.id, ChoiceAnswer(choice: weights.first?.id ?? "", probabilities: probabilities))
            })
    }
}

extension ChoiceQuestion {
    /// The piece this question narrows: its `current_piece`, or `nil` at step 1.
    var currentPiece: String? {
        guard case .onPiece(let currentPiece, _) = instructions else { return nil }
        return currentPiece
    }
}
