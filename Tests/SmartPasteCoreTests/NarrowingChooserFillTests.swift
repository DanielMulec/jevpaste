import Testing

@testable import SmartPasteCore

/// When Jev asks the user, Jev also fills the Candidate Chooser (live finding F1, 2026-09-26; Daniel's decision): the
/// deciding choice is asked again without `ask_user`, in the fill wording, leaving out every piece that overlaps a row
/// found so far; each pick becomes the next row, until Jev keeps the piece or finds nothing fits.
struct NarrowingChooserFillTests {
    private static let personal = "mira.holzner@example.org"
    private static let studio = "m.holzner@studio-holzner.example"
    private static let copy = "Mira Holzner\n\(personal)\n\(studio)\n"
    private static let fillProbability = 0.7

    /// Narrowing on a copy after Jev asked the user at step 1, with the step's request and the first fill request.
    private struct AskedTheUser {
        var narrowing: Narrowing
        let step: NarrowingRequest
        let fill: NarrowingRequest

        var requests: (step: NarrowingRequest, fill: NarrowingRequest) { (step, fill) }
    }

    private static func askedTheUser(copy: String = copy) throws -> AskedTheUser {
        var narrowing = Narrowing(
            item: ClipboardItem(text: copy), context: TargetContext(fieldLabel: "E-Mail"), policy: .r2b)
        guard case .send(let step) = narrowing.start() else { throw FillError.noRequest }
        let action = narrowing.receive(step.answers { _ in [("ask_user", Self.fillProbability)] })
        guard case .send(let fill) = action else { throw FillError.noRequest }
        return AskedTheUser(narrowing: narrowing, step: step, fill: fill)
    }

    @Test func askTheUserAsksTheDecidingChoiceAgainWithoutAskUserInTheFillWording() throws {
        let (step, fill) = try Self.askedTheUser().requests

        let deciding = try #require(step.questions.first)
        let filling = try #require(fill.questions.first)
        #expect(fill.questions.count == 1)
        #expect(filling.id == deciding.id)
        #expect(filling.options.map(\.id) == deciding.options.map(\.id).filter { $0 != "ask_user" })
        #expect(filling.instructions == .wholeCopy(NarrowingPolicy.r2b.wordings.firstStepFillWithExcerptIDs))
        #expect(fill.excerpts == step.excerpts)
        #expect(fill.sourceDocument == step.sourceDocument && fill.targetContext == step.targetContext)
    }

    @Test func aFillPickBecomesARowAndTheNextFillLeavesOutEveryPieceOverlappingAnyOccurrenceOfIt() throws {
        let asked = try Self.askedTheUser()
        var narrowing = asked.narrowing
        let (step, fill) = (asked.step, asked.fill)

        let action = narrowing.receive(fill.picking(Self.personal))

        guard case .send(let next) = action else { throw FillError.noRequest }
        let question = try #require(next.questions.first)
        let offered = question.pieceOptions(in: next).map(\.text)
        #expect(!offered.contains(Self.personal))
        #expect(!offered.contains("\(Self.personal)\n\(Self.studio)"))
        #expect(!offered.contains("holzner"), "also inside the studio address, but one occurrence overlaps the row")
        #expect(offered.contains(Self.studio) && offered.contains("studio") && offered.contains("Mira Holzner"))
        let stepIDs = try #require(step.questions.first).pieceOptions(in: step)
        #expect(question.pieceOptions(in: next).allSatisfy { option in stepIDs.contains { $0 == option } })
        #expect(question.options.map(\.id).suffix(1) == ["nothing_fits"])
    }

    @Test func nothingFitsAfterRowsOpensTheChooserWithTheRowsInTheOrderFound() throws {
        let asked = try Self.askedTheUser()
        var narrowing = asked.narrowing
        let fill = asked.fill
        guard case .send(let second) = narrowing.receive(fill.picking(Self.studio)),
            case .send(let third) = narrowing.receive(second.picking(Self.personal))
        else { throw FillError.noRequest }

        let action = narrowing.receive(third.answers { _ in [("nothing_fits", 0.66)] })

        #expect(action == .askUser([Candidate(text: Self.studio), Candidate(text: Self.personal)]))
        #expect(narrowing.trace.chooserFill == ChooserFillTrace(calls: 3, end: .nothingFits))
        #expect(narrowing.trace.decidingProbability == Self.fillProbability)
    }

    @Test func keepingThePieceAfterARowEndsTheFillToo() throws {
        let asked = try Self.askedTheUser()
        var narrowing = asked.narrowing
        let fill = asked.fill
        guard case .send(let second) = narrowing.receive(fill.picking(Self.personal)) else {
            throw FillError.noRequest
        }

        let action = narrowing.receive(second.answers { question in [(question.options[0].id, 0.5)] })

        #expect(action == .askUser([Candidate(text: Self.personal)]))
        #expect(narrowing.trace.chooserFill == ChooserFillTrace(calls: 2, end: .keep))
    }

    @Test func aFirstFillThatKeepsTheWholeCopyPastesItWithoutItsOuterLineBreaks() throws {
        let asked = try Self.askedTheUser()
        var narrowing = asked.narrowing
        let fill = asked.fill

        let action = narrowing.receive(fill.answers { question in [(question.options[0].id, 0.8)] })

        #expect(action == .pasteResult("Mira Holzner\n\(Self.personal)\n\(Self.studio)"))
        #expect(narrowing.trace.chooserFill == ChooserFillTrace(calls: 1, end: .keep))
    }

    @Test func aFirstFillThatFindsNothingFitsIsNoSuitableMatch() throws {
        let asked = try Self.askedTheUser()
        var narrowing = asked.narrowing
        let fill = asked.fill

        let action = narrowing.receive(fill.answers { _ in [("nothing_fits", 0.8)] })

        #expect(action == .nothingFits)
        #expect(narrowing.trace.chooserFill == ChooserFillTrace(calls: 1, end: .nothingFits))
    }

    @Test func aFillPickThatIsNoLongerOfferedIsAnInvalidPick() throws {
        let asked = try Self.askedTheUser()
        var narrowing = asked.narrowing
        let fill = asked.fill
        let rowID = try #require(fill.questions.first?.optionID(of: Self.personal, in: fill))
        guard case .send = narrowing.receive(fill.picking(Self.personal)) else { throw FillError.noRequest }

        let action = narrowing.receive(fill.answers { _ in [(rowID, 0.9)] })

        #expect(action == .invalidPick)
    }

    @Test func aRowThatOccursTwiceLeavesOutThePiecesOverlappingEitherOccurrence() throws {
        let copy = "ab@x.io\ncd@x.io\nwork: ab@x.io"
        let asked = try Self.askedTheUser(copy: copy)
        var narrowing = asked.narrowing
        let fill = asked.fill

        let action = narrowing.receive(fill.picking("ab@x.io"))

        guard case .send(let next) = action else { throw FillError.noRequest }
        let offered = try #require(next.questions.first).pieceOptions(in: next).map(\.text)
        #expect(!offered.contains("work: ab@x.io") && !offered.contains(": ab"))
        #expect(offered.contains("cd@x.io") && offered.contains("work:"))
    }

    @Test func aFillAtALaterStepAsksAboutTheCurrentPieceAndKeepingItPastesThatPiece() throws {
        let both = "\(Self.personal)\n\(Self.studio)"
        var narrowing = Narrowing(
            item: ClipboardItem(text: Self.copy), context: TargetContext(fieldLabel: "E-Mail"), policy: .r2b)
        guard case .send(let first) = narrowing.start(),
            case .send(let second) = narrowing.receive(first.picking(both)),
            case .send(let fill) = narrowing.receive(second.answers { _ in [("ask_user", 0.6)] })
        else { throw FillError.noRequest }

        let filling = try #require(fill.questions.first)
        let wording = NarrowingPolicy.r2b.wordings.laterStepFillWithExcerptIDs
        #expect(filling.instructions == .onPiece(currentPiece: both, question: wording))
        #expect(filling.options.first == second.questions.first?.options.first)
        #expect(fill.excerpts.first?.text == both)
        #expect(narrowing.receive(fill.answers { question in [(question.options[0].id, 0.9)] }) == .pasteResult(both))
    }

    /// K01 (three emails) is asked in the full-text form, in several choices; all asking the user agree, and the first
    /// of them is the deciding choice.
    @Test func aFillInTheFullTextFormCarriesTheTextsInTheFullTextFillWording() throws {
        let cell = try #require(NarrowingCell.named("K01_three_emails"))
        var narrowing = Narrowing(item: ClipboardItem(text: cell.item), context: cell.targetContext, policy: .r2b)
        guard case .send(let step) = narrowing.start() else { throw FillError.noRequest }
        try #require(step.excerpts.isEmpty && step.questions.count > 1)

        guard case .send(let fill) = narrowing.receive(step.answers { _ in [("ask_user", 0.8)] }) else {
            throw FillError.noRequest
        }

        let filling = try #require(fill.questions.first)
        #expect(filling.instructions == .wholeCopy(NarrowingPolicy.r2b.wordings.firstStepFillWithFullText))
        #expect(filling.options == step.questions[0].options.filter { $0.id != "ask_user" })
        #expect(fill.excerpts.isEmpty)
    }

    private enum FillError: Error { case noRequest }
}

extension NarrowingRequest {
    /// Every question picks the piece whose text is `text`.
    func picking(_ text: String, probability: Double = 0.8) -> [String: ChoiceAnswer] {
        answers { question in [(question.optionID(of: text, in: self) ?? "unoffered", probability)] }
    }
}
