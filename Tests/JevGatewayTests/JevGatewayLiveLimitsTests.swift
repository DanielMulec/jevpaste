import Foundation
import Testing

@testable import JevGateway
@testable import SmartPasteCore

/// Per Jev Provider, live: cold and warm latency of one Narrowing step, and how the provider refuses an oversized
/// request. Only with `JEVPASTE_LIVE_JEV=1` and the provider's key file. Output: numbers, status codes and the
/// refusal's `error_type` — never a key or a body.
@Suite(.serialized) struct JevGatewayLiveLimitsTests {
    private static let warmCalls = 5

    @Test(.enabled(if: LiveJev.isEnabled(for: .vercelAIGateway), "JEVPASTE_LIVE_JEV=1 and a Gateway key file"))
    func coldAndWarmLatencyThroughTheGateway() async throws {
        try await measureColdAndWarmLatency(through: .vercelAIGateway)
    }

    @Test(.enabled(if: LiveJev.isEnabled(for: .typesafeDirect), "JEVPASTE_LIVE_JEV=1 and a Typesafe key file"))
    func coldAndWarmLatencyThroughTypesafeDirect() async throws {
        try await measureColdAndWarmLatency(through: .typesafeDirect)
    }

    @Test(.enabled(if: LiveJev.isEnabled(for: .vercelAIGateway), "JEVPASTE_LIVE_JEV=1 and a Gateway key file"))
    func anOversizedRequestIsTooLargeThroughTheGateway() async throws {
        try await expectAnOversizedRequestIsTooLarge(through: .vercelAIGateway)
    }

    @Test(.enabled(if: LiveJev.isEnabled(for: .typesafeDirect), "JEVPASTE_LIVE_JEV=1 and a Typesafe key file"))
    func anOversizedRequestIsTooLargeThroughTypesafeDirect() async throws {
        try await expectAnOversizedRequestIsTooLarge(through: .typesafeDirect)
    }

    /// A fresh ephemeral session: the first call opens the connection (cold), the next ones reuse it (warm).
    private func measureColdAndWarmLatency(through provider: JevProvider) async throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let service = try LiveJev.service(for: provider, session: session)
        var latencies: [Int] = []
        for _ in 0...Self.warmCalls {
            let started = ContinuousClock.now
            let narrowingReply = await reply(from: service, to: LiveCard.stepOneRequest)
            latencies.append(LiveJev.milliseconds(.now - started))
            guard case .answered = narrowingReply else {
                Issue.record("\(provider.rawValue): \(narrowingReply)")
                return
            }
        }
        let warm = Array(latencies.dropFirst())
        let median = warm.sorted()[warm.count / 2]
        LiveJev.report(
            "live-latency",
            "provider=\(provider.rawValue) cold_ms=\(latencies[0]) "
                + "warm_ms=\(warm.map(String.init).joined(separator: ",")) warm_median_ms=\(median)"
        )
    }

    /// About 400,000 characters of synthetic words — beyond Jev's 64k tokens per request — in one choice question.
    private func expectAnOversizedRequestIsTooLarge(through provider: JevProvider) async throws {
        let apiKey = try #require(LiveJev.apiKey(for: provider))
        let transport = BodyKeepingTransport()
        let service = JevGatewayDecisionService(provider: provider, apiKey: apiKey, transport: transport)
        let oversized = NarrowingRequest(
            sourceDocument: String(repeating: "synthetic filler words ", count: 17_500),
            targetContext: TargetContext(fieldLabel: "Email address"), excerpts: [],
            questions: [
                ChoiceQuestion(
                    id: "probe", instructions: .wholeCopy("Choose."),
                    options: ["a", "b"].map { ChoiceOption(id: $0, description: .text("Option \($0).")) }
                )
            ]
        )

        let narrowingReply = await reply(from: service, to: oversized)

        let (status, body) = try #require(await transport.last)
        let errorType = Self.errorType(in: body)
        LiveJev.report(
            "live-oversized",
            "provider=\(provider.rawValue) status=\(status) error_type=\(errorType) reply=\(narrowingReply) "
                + "request_bytes=\(EvaluateRequestBody.data(for: oversized, model: "-").count)"
        )
        #expect(narrowingReply == .tooLarge)
    }

    /// `max_tokens_exceeded` when the body names it anywhere JevRefusal looks, else the first `error_type` at the
    /// top or under `detail`/`error`, else `none` — a fixed vocabulary word, never free text.
    private static func errorType(in body: Data) -> String {
        if JevRefusal.isTooLarge(body) { return JevRefusal.tooLargeErrorType }
        let json = OrderedJSONParser.parse(body)
        let found = [json?["error_type"], json?["detail"]?["error_type"], json?["error"]?["type"]]
            .compactMap { $0?.stringValue }.first
        return found.map { $0.filter { $0.isLetter || $0 == "_" }.prefix(40) }.map(String.init) ?? "none"
    }
}

/// The production transport, keeping the last status and body for the probe's own reading (never printed).
private actor BodyKeepingTransport: HTTPTransport {
    private(set) var last: (Int, Data)?
    private let transport = URLSessionTransport()

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (body, response) = try await transport.send(request)
        last = (response.statusCode, body)
        return (body, response)
    }
}
