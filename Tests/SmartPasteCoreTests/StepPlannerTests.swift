import Testing

@testable import SmartPasteCore

/// How one step's pieces become choices, and which option form a request uses. Expected values are the spike's
/// `r2.step_chunks` and `cuts.est_tokens` on the same cells (`spike/narrowing` @ ba32886).
struct StepPlannerTests {
    private func planner(for id: String) throws -> (planner: StepPlanner, copy: Substring) {
        let cell = try #require(NarrowingCell.named(id))
        return (StepPlanner(copy: cell.item, context: cell.targetContext, policy: .r2b), cell.item[...])
    }

    private func choiceSizes(_ id: String, form: OptionForm) throws -> [Int] {
        let (planner, copy) = try planner(for: id)
        return planner.choices(on: copy, form: form).map(\.count)
    }

    @Test func theSizeModelCountsLettersAQuarterAndOtherCharactersOneAndWhitespaceNothing() {
        #expect(NarrowingSizeModel.r2b.estimatedTokens(of: "Graz 8020, Ö·\n") == 7.25)
        #expect(NarrowingSizeModel.r2b.questionBudget == 29_440)
        #expect(NarrowingSizeModel.r2b.requestBudget == 58_880)
    }

    @Test func aFewPiecesFitOneChoice() throws {
        #expect(try choiceSizes("A04_hausnummer", form: .excerptIDs) == [112])
    }

    @Test func fewCoarsePiecesAreRepeatedInEveryChoiceAndTheFineRunsSpreadOverThem() throws {
        let (planner, copy) = try planner(for: "R05_about")
        let budget = StepBudget(sizeModel: .r2b, stateTokens: 391.75, questionTokens: 1150, piecesPerChoice: 252)
        let coarse = PieceChildren(of: copy, policy: .r2b, budget: budget).coarse

        let choices = planner.choices(on: copy, form: .excerptIDs)

        #expect(choices.map(\.count) == [252, 252, 54])
        for choice in choices {
            #expect(coarse.allSatisfy { piece in choice.contains { $0.utf8.elementsEqual(piece.utf8) } })
        }
    }

    @Test func manyCoarsePiecesGoInDocumentOrderAcrossTheChoices() throws {
        #expect(try choiceSizes("K01_three_emails", form: .excerptIDs) == [252, 252, 46])
    }

    @Test func piecesAreInDocumentOrderTheLongerFirstAtTheSamePlace() {
        let piece = "Mira Holzner, 8020 Graz"[...]

        let ordered = documentOrder(
            [piece.suffix(4), piece.prefix(4), piece.prefix(12), piece.dropFirst(5)], in: piece)

        #expect(ordered.map(String.init) == ["Mira Holzner", "Mira", "Holzner, 8020 Graz", "Graz"])
    }

    @Test func aPieceIsOrderedByTheFirstPlaceItsTextOccursEvenInsideAWord() {
        let piece = "Mira Grüße, Graz; Rom a Graz"[...]
        let lastGraz = piece.suffix(4)
        let loneA = piece[piece.index(piece.endIndex, offsetBy: -6)...].prefix(1)

        let ordered = documentOrder([lastGraz, loneA, piece.prefix(4), piece.dropFirst(5).prefix(5)], in: piece)

        #expect(ordered.map(String.init) == ["Mira", "a", "Grüße", "Graz"])
    }

    @Test func aRequestThatFitsUsesExcerptIDs() throws {
        let (planner, copy) = try planner(for: "R05_about")

        let assembly = planner.stepRequest(on: copy)

        #expect(assembly.form == .excerptIDs)
        #expect(assembly.questions.map(\.question.id) == ["narrow_0", "narrow_1", "narrow_2"])
        #expect(assembly.request.excerpts.count == 47 + 417)
    }

    @Test func whenTheExcerptIDsWouldOverfillTheStateTheFullTextFormIsResplitByItsOwnBudget() throws {
        let (planner, copy) = try planner(for: "N03_list_300_lines")

        let assembly = planner.stepRequest(on: copy)

        #expect(try choiceSizes("N03_list_300_lines", form: .excerptIDs) == [252, 50])
        #expect(assembly.form == .fullText)
        #expect(assembly.questions.map { $0.question.options.count - 3 } == [151, 151])
        #expect(assembly.request.excerpts.isEmpty)
    }

    @Test func aCopyTooBigForOneCallIsStillPlannedAndSent() throws {
        let lines = (0..<3000).map { "2026-09-12 08:00:\($0 % 60) INFO sync-\($0 % 5) batch flushed in \($0) ms" }
        let copy = lines.joined(separator: "\n")
        let planner = StepPlanner(copy: copy, context: TargetContext(fieldLabel: "Code"), policy: .r2b)

        let assembly = planner.stepRequest(on: copy[...])

        #expect(assembly.form == .fullText)
        #expect(!assembly.fitsJev)
        #expect(assembly.questions.count == 12)
        #expect(assembly.questions.reduce(0) { $0 + $1.question.options.count - 3 } == 3000)
    }
}
