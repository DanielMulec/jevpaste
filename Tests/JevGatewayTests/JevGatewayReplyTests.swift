import JevGateway
import SmartPasteCore
import Testing

private func reply(toBody body: String, status: Int = 200) async throws -> DecisionReply {
    let transport = StubTransport.answering(status: status, body: body)
    return await reply(from: try Fixture.service(transport: transport))
}

@Suite struct JevGatewayReplyTests {
    @Test func chosenOptionIdMapsBackToTheOfferedCandidate() async throws {
        let decisionReply = try await reply(toBody: Fixture.evaluateResponse(choice: "c001", containsValue: 0.97))

        let expected = Decision(choice: .candidate(Candidate(text: "ada@example.org")), containsValueProbability: 0.97)
        #expect(decisionReply == .decided(expected))
    }

    @Test func noneOfTheseMapsToNoneOfThese() async throws {
        let decisionReply = try await reply(
            toBody: Fixture.evaluateResponse(choice: "none_of_these", containsValue: 0.02)
        )

        #expect(decisionReply == .decided(Decision(choice: .noneOfThese, containsValueProbability: 0.02)))
    }

    @Test func aLowBooleanGateIsReportedAsIsForCoreToJudge() async throws {
        let decisionReply = try await reply(toBody: Fixture.evaluateResponse(choice: "c002", containsValue: 0.17))

        let expected = Decision(choice: .candidate(Candidate(text: "London")), containsValueProbability: 0.17)
        #expect(decisionReply == .decided(expected))
    }

    @Test(arguments: ["c003", "c999", "c-01", "c1", "x000", ""])
    func aChoiceOutsideTheOfferedOptionsFails(choice: String) async throws {
        #expect(try await reply(toBody: Fixture.evaluateResponse(choice: choice, containsValue: 0.9)) == .failed)
    }

    @Test(arguments: [-0.01, 1.01])
    func aGateProbabilityOutsideZeroToOneFails(probability: Double) async throws {
        let body = Fixture.evaluateResponse(choice: "c001", containsValue: probability)
        #expect(try await reply(toBody: body) == .failed)
    }

    @Test(arguments: [
        "not json",
        "{}",
        #"{"answers":{"paste":{"type":"choice","choice":"c001"}}}"#,
        #"{"answers":{"contains_value":{"type":"boolean","probability":0.9}}}"#,
        #"{"answers":{"paste":{"choice":1},"contains_value":{"probability":0.9}}}"#,
        #"{"answers":{"paste":{"choice":"c001"},"contains_value":{"probability":"high"}}}"#,
    ])
    func aMalformedResponseFails(body: String) async throws {
        #expect(try await reply(toBody: body) == .failed)
    }

    @Test(arguments: [400, 401, 403, 500, 502, 529])
    func anErrorStatusOtherThan429Fails(status: Int) async throws {
        let body = Fixture.evaluateResponse(choice: "c001", containsValue: 0.9)
        #expect(try await reply(toBody: body, status: status) == .failed)
    }

    @Test func aTransportErrorFails() async throws {
        let transport = StubTransport(.transportError)
        #expect(await reply(from: try Fixture.service(transport: transport)) == .failed)
    }
}
