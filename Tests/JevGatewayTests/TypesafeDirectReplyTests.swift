import Foundation
import SmartPasteCore
import Testing

@testable import JevGateway

private func reply(status: Int = 200, headers: [String: String] = [:], body: String) async -> NarrowingReply {
    let transport = StubTransport.answering(status: status, headers: headers, body: body)
    return await reply(from: Fixture.service(provider: .typesafeDirect, transport: transport))
}

/// Typesafe direct through the same request path as the Gateway: only the endpoint and the pinned model differ, and
/// its own error forms map by fixture (TypeSafe OpenAPI 0.2.0 and the unauthenticated probe, see
/// docs/design/jev-gateway.md).
@Suite struct TypesafeDirectReplyTests {
    @Test func theRequestGoesToTypesafeWithThePinnedModelAndTheSameStateAndQuestions() async throws {
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "x0001"))

        _ = await reply(from: Fixture.service(provider: .typesafeDirect, transport: transport))

        let sent = try #require(await transport.sentRequests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.absoluteString == "https://api.typesafe.ai/v1/systemone")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer test-key-value")
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let gatewayBody = try #require(
            String(bytes: EvaluateRequestBody.data(for: Fixture.request, model: "typesafe-ai/jev"), encoding: .utf8))
        let directBody = try #require(sent.httpBody.flatMap { String(bytes: $0, encoding: .utf8) })
        #expect(gatewayBody.hasPrefix(#"{"model":"typesafe-ai/jev","state":"#))
        #expect(
            directBody
                == gatewayBody.replacingOccurrences(of: #""model":"typesafe-ai/jev""#, with: #""model":"jev-1.13.0""#)
        )
    }

    /// A `200` in TypeSafe's own shape: `confidence`, snake_case `usage`, the answered model, no `providerMetadata`.
    @Test func anAnswerInTypesafesShapeIsPassedOn() async {
        let body = """
            {"model":"jev-1.13.0","answers":{"narrow_0":{"type":"choice","choice":"x0001",
              "probabilities":{"x0001":0.95,"ask_user":0.05},"confidence":0.93}},
             "usage":{"input_tokens":812,"output_tokens":0}}
            """
        let expected = ChoiceAnswer(
            choice: "x0001",
            probabilities: [
                .init(optionID: "x0001", probability: 0.95), .init(optionID: "ask_user", probability: 0.05),
            ]
        )

        #expect(await reply(body: body) == .answered(["narrow_0": expected]))
    }

    @Test(arguments: [
        (["retry-after-ms": "750"], Duration.milliseconds(750)),
        (["retry-after-ms": "250", "retry-after": "7"], .milliseconds(250)),
        (["retry-after": "2"], .seconds(2)),
        ([:], .seconds(1)),
        (["retry-after-ms": "soon"], .seconds(1)),
        (["retry-after-ms": "120000"], .seconds(60)),
    ])
    func aRateLimitWaitsWhatTheHeadersSayMillisecondsFirst(headers: [String: String], wait: Duration) async {
        #expect(await reply(status: 429, headers: headers, body: Self.rateLimitBody) == .rateLimited(retryAfter: wait))
    }

    @Test func overloadedIsARateLimitWithTheSameWait() async {
        let overloaded = #"{"detail":{"error_type":"overloaded_error","message":"Overloaded"}}"#

        #expect(await reply(status: 529, body: overloaded) == .rateLimited(retryAfter: .seconds(1)))
        let told = await reply(status: 529, headers: ["retry-after-ms": "400"], body: overloaded)
        #expect(told == .rateLimited(retryAfter: .milliseconds(400)))
    }

    @Test(arguments: [
        #"{"error_type":"max_tokens_exceeded"}"#,
        #"{"detail":{"error_type":"max_tokens_exceeded","message":"Too many tokens."}}"#,
    ])
    func jevRefusingTheSizeIsTooLarge(body: String) async {
        #expect(await reply(status: 400, body: body) == .tooLarge)
    }

    /// 401 and 403 (a missing key gets 403 in practice, the docs say 401), validation 422, others: `.failed`, never
    /// `.tooLarge` although the auth error carries an `error_type` under `detail` too.
    @Test(arguments: [401, 403, 400, 402, 422, 500, 503])
    func anyOtherErrorFails(status: Int) async {
        #expect(await reply(status: status, body: Self.authenticationError) == .failed)
        #expect(await reply(status: status, body: Self.validationError) == .failed)
    }

    /// The answered `model` goes to the log: only as an id — letters, digits, `.`, `-`, `_`, `/`, at most 40 of them.
    @Test(
        arguments: [
            (#"{"model":"jev-1.13.0","answers":{}}"#, "jev-1.13.0"),
            (#"{"model":"typesafe-ai/jev","answers":{}}"#, "typesafe-ai/jev"),
            (#"{"model":"jev 1.13\n<b>x</b>","answers":{}}"#, "jev1.13bx/b"),
            (#"{"model":"\#(String(repeating: "j", count: 50))"}"#, String(repeating: "j", count: 40)),
            (#"{"model":7}"#, nil), (#"{"answers":{}}"#, nil), ("not json", nil),
        ] as [(String, String?)])
    func theAnsweredModelIsReadAsAnIDOnly(body: String, model: String?) {
        #expect(EvaluateResponse.answeredModel(in: Data(body.utf8)) == model)
    }

    private static let rateLimitBody = #"{"detail":{"error_type":"rate_limit_error","message":"Rate limited"}}"#
    /// The body of the unauthenticated probe (2026-09-25 and at Gate A).
    private static let authenticationError = """
        {"detail":{"error_type":"authentication_error","message":"Must supply an API key! Check your request and \
        try again."}}
        """
    /// FastAPI's validation shape (OpenAPI `HTTPValidationError`).
    private static let validationError = """
        {"detail":[{"loc":["body","questions","narrow_0","type"],"msg":"Input tag 'boolean' found",\
        "type":"union_tag_invalid"}]}
        """
}
