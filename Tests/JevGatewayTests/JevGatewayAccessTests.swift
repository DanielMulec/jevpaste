import Foundation
import SmartPasteCore
import Testing

@testable import JevGateway

/// API keys by provider, as the Keychain would hold them.
struct FakeJevCredentials: JevCredentials {
    var keys: [JevProvider: String]

    func apiKey(for provider: JevProvider) -> String? {
        keys[provider]
    }
}

/// Opening the chosen Jev Provider at ⌘⇧V: its key is read then, once, and never swapped for another provider's.
@MainActor
@Suite struct JevGatewayAccessTests {
    private static func access(
        keys: [JevProvider: String], chosen: JevProvider = .vercelAIGateway, transport: StubTransport
    ) -> JevGatewayAccess {
        JevGatewayAccess(
            credentials: FakeJevCredentials(keys: keys), chosenProvider: { chosen }, transport: transport
        )
    }

    @Test(arguments: [nil, ""])
    func theChosenProviderWithoutAKeyIsReportedAndNothingIsSent(key: String?) async {
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "x0001"))
        let keys: [JevProvider: String] = key.map { [.vercelAIGateway: $0] } ?? [:]

        let opening = Self.access(keys: keys, transport: transport).openForPasteAttempt()

        guard case .noKey(let provider) = opening else {
            Issue.record("expected no key")
            return
        }
        #expect(provider == .vercelAIGateway)
        #expect(await transport.sentRequests.isEmpty)
    }

    /// Each provider is served through its own endpoint with its own key — never the other's, whichever keys exist.
    @Test(arguments: [
        (JevProvider.vercelAIGateway, "https://ai-gateway.vercel.sh/v1/evaluate", "Bearer fake-gateway-key"),
        (.typesafeDirect, "https://api.typesafe.ai/v1/systemone", "Bearer fake-typesafe-key"),
    ])
    func theChosenProviderIsServedThroughItsOwnEndpointWithItsOwnKey(
        chosen: JevProvider, url: String, authorization: String
    ) async throws {
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "x0001"))
        let keys: [JevProvider: String] = [.vercelAIGateway: "fake-gateway-key", .typesafeDirect: "fake-typesafe-key"]

        guard
            case .ready(let service) = Self.access(keys: keys, chosen: chosen, transport: transport)
                .openForPasteAttempt()
        else {
            Issue.record("expected \(chosen) to open")
            return
        }
        _ = await reply(from: service)

        let sent = try #require(await transport.sentRequests.first)
        #expect(sent.url?.absoluteString == url)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == authorization)
    }

    @Test func typesafeDirectWithoutAKeyIsReportedAndNeverServedByTheGateway() async {
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "x0001"))
        let access = Self.access(
            keys: [.vercelAIGateway: "fake-gateway-key"], chosen: .typesafeDirect, transport: transport)

        guard case .noKey(let provider) = access.openForPasteAttempt() else {
            Issue.record("expected typesafe direct to have no key")
            return
        }
        #expect(provider == .typesafeDirect)
        #expect(await transport.sentRequests.isEmpty)
    }
}
