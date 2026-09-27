import Foundation
import SmartPasteCore
import Testing

@testable import JevGateway

private func reply(toBody body: String, status: Int = 200) async throws -> NarrowingReply {
    let transport = StubTransport.answering(status: status, body: body)
    return await reply(from: Fixture.service(transport: transport))
}

/// The two 400 bodies the spike recorded when Jev refused the size (`results/raw.jsonl`, cell `N04_probe`), cut to
/// the parts the adapter reads plus some of the noise around them.
private enum RecordedRefusal {
    static let direct = #"""
        {"error":{"message":"{\"error_type\":\"max_tokens_exceeded\"}","type":"AI_APICallError",
         "param":{"error":"{\"error_type\":\"max_tokens_exceeded\"}","statusCode":400,"isRetryable":false}},
         "providerMetadata":{"gateway":{"routing":{"modelAttempts":[{"success":false,"providerAttempts":[
          {"provider":"typesafe-ai","success":false,"error":"{\"error_type\":\"max_tokens_exceeded\"}",
           "statusCode":400},
          {"provider":"digitalocean","success":false,"error":"Service temporarily unavailable","statusCode":503}]}]}}}}
        """#
    static let fallback = #"""
        {"error":{"message":"typesafe returned status 400","type":"AI_APICallError",
         "param":{"error":"typesafe returned status 400","statusCode":400,"isRetryable":false}},
         "providerMetadata":{"gateway":{"routing":{"modelAttempts":[{"success":false,"providerAttempts":[
          {"provider":"typesafe-ai","success":false,"error":"{\"error_type\":\"max_tokens_exceeded\"}",
           "statusCode":400},
          {"provider":"digitalocean","success":false,"error":"typesafe returned status 400","statusCode":400}]}]}}}}
        """#
}

@Suite struct NarrowingReplyTests {
    @Test func theChosenOptionAndEveryProbabilityArePassedOnInJevsOrder() async throws {
        let narrowingReply = try await reply(toBody: Fixture.evaluateResponse(choice: "x0001", probability: 0.97))

        let expected = ChoiceAnswer(
            choice: "x0001",
            probabilities: [
                OptionProbability(optionID: "x0002", probability: 0),
                OptionProbability(optionID: "x0001", probability: 0.97),
                OptionProbability(optionID: "ask_user", probability: 0.01),
            ]
        )
        #expect(narrowingReply == .answered(["narrow_0": expected]))
    }

    @Test(arguments: ["everything", "nothing_fits", "ask_user"])
    func aFixedOptionIsPassedOnLikeAnyOther(choice: String) async throws {
        let narrowingReply = try await reply(toBody: Fixture.evaluateResponse(choice: choice))

        guard case .answered(let answers) = narrowingReply else {
            Issue.record("expected answers, got \(narrowingReply)")
            return
        }
        #expect(answers["narrow_0"]?.choice == choice)
    }

    @Test(arguments: ["x0003", "keep", "e000", "none_of_these", ""])
    func aChoiceTheQuestionDidNotOfferFails(choice: String) async throws {
        #expect(try await reply(toBody: Fixture.evaluateResponse(choice: choice)) == .failed)
    }

    @Test(arguments: [-0.01, 1.01])
    func aProbabilityOutsideZeroToOneFails(probability: Double) async throws {
        let body = Fixture.evaluateResponse(choice: "x0001", probability: probability)
        #expect(try await reply(toBody: body) == .failed)
    }

    @Test(arguments: [
        "not json",
        "{}",
        #"{"answers":{}}"#,
        #"{"answers":{"narrow_0":{"choice":"x0001"}}}"#,
        #"{"answers":{"narrow_0":{"choice":1,"probabilities":{"x0001":1}}}}"#,
        #"{"answers":{"narrow_0":{"choice":"x0001","probabilities":{"x0001":"high"}}}}"#,
        #"{"answers":{"other":{"choice":"x0001","probabilities":{"x0001":1}}}}"#,
    ])
    func aMalformedResponseOrAMissingAnswerFails(body: String) async throws {
        #expect(try await reply(toBody: body) == .failed)
    }

    @Test(arguments: [RecordedRefusal.direct, RecordedRefusal.fallback, #"{"error_type":"max_tokens_exceeded"}"#])
    func jevRefusingTheSizeIsTooLarge(body: String) async throws {
        #expect(try await reply(toBody: body, status: 400) == .tooLarge)
    }

    @Test(arguments: [
        #"{"error":{"message":"invalid request: max_tokens_exceeded appears in your text"}}"#,
        #"{"error":{"message":"{\"error_type\":\"invalid_request\"}"}}"#,
        "max_tokens_exceeded",
    ])
    func anyOther400Fails(body: String) async throws {
        #expect(try await reply(toBody: body, status: 400) == .failed)
    }

    @Test(arguments: [401, 403, 413, 500, 502, 529])
    func anErrorStatusOtherThan400And429Fails(status: Int) async throws {
        #expect(try await reply(toBody: RecordedRefusal.direct, status: status) == .failed)
    }

    @Test func aTransportErrorFails() async throws {
        let transport = StubTransport(.transportError)
        #expect(await reply(from: Fixture.service(transport: transport)) == .failed)
    }

    @Test func theRequestIsOnePostWithTheKeyAndTheBody() async throws {
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "x0001"))

        _ = await reply(from: Fixture.service(transport: transport))

        let sent = try #require(await transport.sentRequests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.absoluteString == "https://ai-gateway.vercel.sh/v1/evaluate")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer test-key-value")
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(sent.httpBody == EvaluateRequestBody.data(for: Fixture.request))
        #expect(await transport.sentRequests.count == 1)
    }
}
