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

    @Test func theChosenGatewaysKeyIsSentWithEveryRequestOfTheAttempt() async throws {
        let transport = StubTransport.answering(body: Fixture.evaluateResponse(choice: "x0001"))
        let access = Self.access(keys: [.vercelAIGateway: "fake-gateway-key"], transport: transport)

        guard case .ready(let service) = access.openForPasteAttempt() else {
            Issue.record("expected the gateway to open")
            return
        }
        _ = await reply(from: service)

        let sent = try #require(await transport.sentRequests.first)
        #expect(sent.url?.absoluteString == "https://ai-gateway.vercel.sh/v1/evaluate")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer fake-gateway-key")
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

    /// Typesafe direct has no adapter until "Add Typesafe direct as a Jev Provider"; Settings cannot choose it. Were
    /// it chosen anyway, nothing goes to the Gateway in its place.
    @Test func typesafeDirectIsNeverServedByTheGateway() {
        let access = Self.access(
            keys: [.vercelAIGateway: "fake-gateway-key", .typesafeDirect: "fake-typesafe-key"], chosen: .typesafeDirect,
            transport: StubTransport.answering(body: "{}")
        )

        guard case .noKey(let provider) = access.openForPasteAttempt() else {
            Issue.record("expected typesafe direct to stay unserved")
            return
        }
        #expect(provider == .typesafeDirect)
    }
}
