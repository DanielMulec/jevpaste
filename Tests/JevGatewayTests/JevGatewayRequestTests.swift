import Foundation
import JevGateway
import SmartPasteCore
import Testing

/// The wire body as Jev receives it, decoded independently of the adapter's own encoding types.
private struct SentBody: Decodable {
    let model: String
    let questions: SentQuestions
}

/// `state`, decoded with `.convertFromSnakeCase` so the test names no wire keys of its own.
private struct SentStateEnvelope: Decodable {
    let state: SentState
}

private struct SentState: Decodable {
    let sourceDocument: String
    let targetContext: SentTargetContext
}

private struct SentTargetContext: Decodable {
    let fieldLabel: String?
    let placeholder: String?
    let sectionHeading: String?
    let siblingFieldLabels: [String]?
    let surroundingText: String?
}

private struct SentQuestions: Decodable {
    let paste: SentQuestion
    let containsValue: SentQuestion

    enum CodingKeys: String, CodingKey {
        case paste
        case containsValue = "contains_value"
    }
}

private struct SentQuestion: Decodable {
    let type: String
    let instructions: String
    let criteria: [String: String]
}

private func sentBodyData(for request: DecisionRequest) async throws -> Data {
    let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "c000", containsValue: 0.9))
    _ = await reply(from: try Fixture.service(transport: transport), to: request)
    let sent = await transport.sentRequests
    return try #require(sent.first?.httpBody)
}

private func sentBody(for request: DecisionRequest) async throws -> SentBody {
    try JSONDecoder().decode(SentBody.self, from: try await sentBodyData(for: request))
}

private func sentState(for request: DecisionRequest) async throws -> SentState {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(SentStateEnvelope.self, from: try await sentBodyData(for: request)).state
}

@Suite struct JevGatewayRequestTests {
    @Test func postsOneEvaluationToTheGatewayWithTheKeyAsBearerToken() async throws {
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "c001", containsValue: 0.97))
        _ = await reply(from: try Fixture.service(transport: transport))

        let sent = await transport.sentRequests
        #expect(sent.count == 1)
        #expect(sent.first?.httpMethod == "POST")
        #expect(sent.first?.url?.absoluteString == "https://ai-gateway.vercel.sh/v1/evaluate")
        #expect(sent.first?.value(forHTTPHeaderField: "Authorization") == "Bearer test-key-value")
        #expect(sent.first?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func statePairsTheSourceDocumentWithEveryTargetContextField() async throws {
        let state = try await sentState(for: Fixture.request)

        #expect(try await sentBody(for: Fixture.request).model == "typesafe-ai/jev")
        #expect(state.sourceDocument == Fixture.request.sourceDocument)
        #expect(state.targetContext.fieldLabel == "Email address")
        #expect(state.targetContext.placeholder == "you@example.com")
        #expect(state.targetContext.sectionHeading == "Contact")
        #expect(state.targetContext.siblingFieldLabels == ["Full name"])
        #expect(state.targetContext.surroundingText == "Sign up for the newsletter")
    }

    @Test func absentAndEmptyTargetContextFieldsAreLeftOut() async throws {
        let bareRequest = DecisionRequest(
            sourceDocument: Fixture.request.sourceDocument,
            targetContext: TargetContext(fieldLabel: "Email address"),
            candidates: Fixture.candidates
        )
        let context = try await sentState(for: bareRequest).targetContext

        #expect(context.fieldLabel == "Email address")
        #expect(context.placeholder == nil)
        #expect(context.sectionHeading == nil)
        #expect(context.siblingFieldLabels == nil)
        #expect(context.surroundingText == nil)
    }

    @Test func choiceQuestionOffersEveryCandidateByIndexPlusNoneOfThese() async throws {
        let paste = try await sentBody(for: Fixture.request).questions.paste

        #expect(paste.type == "choice")
        #expect(!paste.instructions.isEmpty)
        #expect(Set(paste.criteria.keys) == ["c000", "c001", "c002", "none_of_these"])
        #expect(paste.criteria["c000"] == "Ada Lovelace")
        #expect(paste.criteria["c001"] == "ada@example.org")
        #expect(paste.criteria["c002"] == "London")
        #expect(paste.criteria["none_of_these"]?.isEmpty == false)
    }

    @Test func booleanGateAsksWhetherTheDocumentContainsAValue() async throws {
        let gate = try await sentBody(for: Fixture.request).questions.containsValue

        #expect(gate.type == "boolean")
        #expect(!gate.instructions.isEmpty)
        #expect(Set(gate.criteria.keys) == ["true", "false"])
    }

    @Test func candidateDescriptionsBecomeOneLineOfAtMost255Characters() async throws {
        let longLine = String(repeating: "x", count: 300)
        let request = DecisionRequest(
            sourceDocument: "first\nsecond " + longLine,
            targetContext: TargetContext(fieldLabel: "Notes"),
            candidates: [Candidate(text: "first\nsecond"), Candidate(text: longLine)]
        )
        let criteria = try await sentBody(for: request).questions.paste.criteria

        #expect(criteria["c000"] == "first second")
        #expect(criteria["c001"] == String(repeating: "x", count: 255))
    }

    @Test func moreThan254CandidatesFailWithoutACall() async throws {
        let candidates = (0..<255).map { Candidate(text: "value \($0)") }
        let request = DecisionRequest(
            sourceDocument: candidates.map(\.text).joined(separator: "\n"),
            targetContext: TargetContext(fieldLabel: "Anything"),
            candidates: candidates
        )
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "c000", containsValue: 0.9))

        #expect(await reply(from: try Fixture.service(transport: transport), to: request) == .failed)
        #expect(await transport.sentRequests.isEmpty)
    }
}
