import Foundation
import Testing

@testable import JevGateway
@testable import SmartPasteCore

/// Every wording of design `r2b`, written out verbatim from `spikes/narrowing/round2/FINDINGS.md` ("Every wording,
/// verbatim", `spike/narrowing` @ ba32886) and the brief's full-text sentences — independent of `NarrowingWordings`.
private enum FrozenWording {
    static let preamble =
        "The user copied `source_document` and pressed paste. `target_context` describes the place where the text "
        + "cursor is, and what surrounds that place. "
    static let firstStepIDs =
        preamble
        + "One option is everything that was copied, as it is. Every other excerpt option is the id of an exact "
        + "excerpt cut from `source_document`; `excerpts` gives the text of each id, character for character. "
        + "Choose what will be pasted at the text cursor. If that place asks for one particular thing, choose the "
        + "option that is exactly that thing, with nothing missing and nothing extra; only if no option is exactly "
        + "that, choose the option that contains all of it with the least extra text. If that place does not ask "
        + "for one particular thing, choose everything that was copied. If two or more different excerpts are each "
        + "exactly the thing that place asks for and nothing says which one is meant, choose `ask_user` instead of "
        + "one of them."
    static let laterStepIDs =
        preamble
        + "`current_piece` is an exact excerpt of `source_document`. One option is `current_piece` kept as it is. "
        + "Every other excerpt option is the id of a smaller exact excerpt cut from `current_piece`; `excerpts` "
        + "gives the text of each id, character for character. Choose what will be pasted at the text cursor. If "
        + "that place asks for one particular thing, choose the option that is exactly that thing, with nothing "
        + "missing and nothing extra; only if no option is exactly that, choose the option that contains all of it "
        + "with the least extra text. If that place does not ask for one particular thing, choose `current_piece` "
        + "as it is. If two or more different excerpts are each exactly the thing that place asks for and nothing "
        + "says which one is meant, choose `ask_user` instead of one of them."
    static let firstStepFullText = firstStepIDs.replacingOccurrences(
        of: "Every other excerpt option is the id of an exact excerpt cut from `source_document`; `excerpts` gives "
            + "the text of each id, character for character.",
        with: "Every other excerpt option is an exact excerpt cut from `source_document`; its description is that "
            + "excerpt, character for character."
    )
    static let laterStepFullText = laterStepIDs.replacingOccurrences(
        of: "Every other excerpt option is the id of a smaller exact excerpt cut from `current_piece`; `excerpts` "
            + "gives the text of each id, character for character.",
        with: "Every other excerpt option is a smaller exact excerpt cut from `current_piece`; its description is that "
            + "excerpt, character for character."
    )
    /// The Candidate Chooser's fill wordings (Daniel, 2026-09-26): each step wording without its last sentence.
    static let askUserSentence =
        " If two or more different excerpts are each exactly the thing that place asks for and nothing says which "
        + "one is meant, choose `ask_user` instead of one of them."
    static let firstStepFillIDs = firstStepIDs.replacingOccurrences(of: askUserSentence, with: "")
    static let laterStepFillIDs = laterStepIDs.replacingOccurrences(of: askUserSentence, with: "")
    static let firstStepFillFullText = firstStepFullText.replacingOccurrences(of: askUserSentence, with: "")
    static let laterStepFillFullText = laterStepFullText.replacingOccurrences(of: askUserSentence, with: "")
    static let everything = "Everything that was copied, as it is: all of `source_document`, nothing cut away."
    static let keep = "`current_piece` as it is, nothing cut away."
    static let nothingFits = "That place asks for one particular thing, and no part of `source_document` is that thing."
    static let askUser =
        "That place asks for one particular thing, two or more different excerpts of `source_document` are each "
        + "exactly that thing, and nothing says which one is meant; the user has to pick."
}

/// The body as Jev receives it, read back as a JSON value.
private func sent(_ request: NarrowingRequest) throws -> OrderedJSON {
    try #require(OrderedJSONParser.parse(EvaluateRequestBody.data(for: request)))
}

private func question(_ id: String, of request: NarrowingRequest) throws -> OrderedJSON {
    try #require(try sent(request)["questions"]?[id])
}

private func excerpts(of request: NarrowingRequest) throws -> [String: String]? {
    try sent(request)["state"]?["excerpts"]?.objectMembers.map { members in
        Dictionary(uniqueKeysWithValues: members.map { ($0.key, $0.value.stringValue ?? "") })
    }
}

private func assembly(
    copy: String, form: OptionForm, piece: Substring? = nil, pieces: [Substring]
) -> NarrowingRequest {
    var assembly = RequestAssembly(copy: copy, context: TargetContext(fieldLabel: "Ort"), policy: .r2b, form: form)
    assembly.addChoice(id: "narrow_0", on: piece ?? copy[...], offering: pieces)
    return assembly.request
}

struct NarrowingRequestEncodingTests {
    private static let copy = "Mira Holzner\nPrankergasse 77\n8020 Graz"

    @Test func step1InTheExcerptIDFormCarriesEveryWordingVerbatim() throws {
        let copy = Self.copy
        let request = assembly(copy: copy, form: .excerptIDs, pieces: [copy.suffix(4), copy.prefix(4)])

        let sent = try question("narrow_0", of: request)

        #expect(sent["type"] == .string("choice"))
        #expect(sent["instructions"] == .string(FrozenWording.firstStepIDs))
        #expect(sent["criteria"]?["everything"] == .string(FrozenWording.everything))
        #expect(sent["criteria"]?["nothing_fits"] == .string(FrozenWording.nothingFits))
        #expect(sent["criteria"]?["ask_user"] == .string(FrozenWording.askUser))
        #expect(sent["criteria"]?["x0000"] == .null && sent["criteria"]?["x0001"] == .null)
        #expect(try excerpts(of: request) == ["x0000": "Graz", "x0001": "Mira"])
    }

    @Test func aLaterStepInTheExcerptIDFormKeepsThePieceAsItsOwnExcerptID() throws {
        let copy = Self.copy
        let piece = copy.suffix(9)
        let request = assembly(copy: copy, form: .excerptIDs, piece: piece, pieces: [piece.suffix(4)])

        let sent = try question("narrow_0", of: request)

        #expect(sent["instructions"]?["current_piece"] == .string("8020 Graz"))
        #expect(sent["instructions"]?["question"] == .string(FrozenWording.laterStepIDs))
        #expect(sent["criteria"]?["x0000"] == .string(FrozenWording.keep))
        #expect(try excerpts(of: request) == ["x0000": "8020 Graz", "x0001": "Graz"])
    }

    @Test func theFullTextFormCarriesEveryExcerptVerbatimWithRealLineBreaksAndNoLengthCut() throws {
        let long = String(repeating: "Prankergasse 77, ", count: 40) + "Top 11"
        let copy = "Mira Holzner\n" + long + "\n8020 Graz"
        let piece = copy.dropFirst(13)
        let first = assembly(copy: copy, form: .fullText, pieces: [piece])
        let later = assembly(copy: copy, form: .fullText, piece: piece, pieces: [piece.prefix(long.count)])

        let firstSent = try question("narrow_0", of: first)
        let laterSent = try question("narrow_0", of: later)

        #expect(firstSent["instructions"] == .string(FrozenWording.firstStepFullText))
        #expect(firstSent["criteria"]?["e000"] == .string(long + "\n8020 Graz"))
        #expect(laterSent["instructions"]?["question"] == .string(FrozenWording.laterStepFullText))
        #expect(laterSent["criteria"]?["keep"]?["option"] == .string(FrozenWording.keep))
        #expect(laterSent["criteria"]?["keep"]?["text"] == .string(long + "\n8020 Graz"))
        #expect(laterSent["criteria"]?["e000"] == .string(long))
        #expect(try excerpts(of: first) == nil)
    }

    @Test(arguments: [
        (OptionForm.excerptIDs, false, FrozenWording.firstStepFillIDs),
        (.excerptIDs, true, FrozenWording.laterStepFillIDs),
        (.fullText, false, FrozenWording.firstStepFillFullText),
        (.fullText, true, FrozenWording.laterStepFillFullText),
    ])
    func aFillChoiceCarriesItsStepWordingWithoutTheAskUserSentenceAndNoAskUserOption(
        form: OptionForm, isLaterStep: Bool, wording: String
    ) throws {
        let copy = Self.copy
        let piece = isLaterStep ? copy.suffix(9) : copy[...]
        var assembly = RequestAssembly(copy: copy, context: TargetContext(fieldLabel: "Ort"), policy: .r2b, form: form)
        assembly.addChoice(id: "narrow_0", on: piece, offering: [copy.suffix(4)])
        let fill = ChooserFill(deciding: try #require(assembly.questions.first))
        let (planned, excerpts) = fill.nextQuestion(wordings: NarrowingPolicy.r2b.wordings)
        let request = NarrowingRequest(
            sourceDocument: copy, targetContext: TargetContext(fieldLabel: "Ort"), excerpts: excerpts,
            questions: [planned.question])

        let sent = try question("narrow_0", of: request)

        let instructions = isLaterStep ? sent["instructions"]?["question"] : sent["instructions"]
        #expect(instructions == .string(wording))
        #expect(sent["criteria"]?["ask_user"] == nil)
        #expect(sent["criteria"]?["nothing_fits"] == .string(FrozenWording.nothingFits))
    }

    @Test func theBodyIsTheModelThenCoresStateAndQuestionsInOrder() {
        let body = String(bytes: EvaluateRequestBody.data(for: Fixture.request), encoding: .utf8)

        let expected =
            #"{"model":"typesafe-ai/jev","state":{"#
            + #""source_document":"Name: Ada Lovelace\nEmail: ada@example.org\nCity: London","#
            + #""target_context":{"field_label":"Email address","placeholder":"you@example.com","#
            + #""section_heading":"Contact","sibling_field_labels":["Full name"],"#
            + #""surrounding_text":"Sign up for the newsletter"},"#
            + #""excerpts":{"x0000":"Ada Lovelace","x0001":"ada@example.org","x0002":"London"}},"#
            + #""questions":{"narrow_0":{"type":"choice","instructions":"Choose.","criteria":{"#
            + #""everything":"The everything option.","x0000":null,"x0001":null,"x0002":null,"#
            + #""nothing_fits":"The nothing_fits option.","ask_user":"The ask_user option."}}}}"#
        #expect(body == expected)
    }

    @Test func theTargetContextLeavesOutAbsentAndEmptyFieldsAndPutsTheAppFirst() {
        let context = TargetContext(
            fieldLabel: "Message", placeholder: "", siblingFieldLabels: [], surroundingText: "hi", appName: "Ghostty",
            windowTitle: "zsh"
        )

        let rendered = context.json.rendered

        let expected = #"{"app_name":"Ghostty","window_title":"zsh","field_label":"Message","surrounding_text":"hi"}"#
        #expect(rendered == expected)
    }

    @Test func textIsEscapedAsPythonsJSONDumpsWithoutASCIIEscapingWouldWriteIt() {
        let text = OrderedJSON.string("\"\\\n\r\t\u{08}\u{0C}\u{01}\u{1F}/Ö👍🏽\u{2028}")

        #expect(text.rendered == #""\"\\\n\r\t\b\f\u0001\u001f/Ö👍🏽"# + "\u{2028}\"")
    }
}
