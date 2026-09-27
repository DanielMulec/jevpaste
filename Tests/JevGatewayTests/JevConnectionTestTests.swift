import Foundation
import SmartPasteCore
import Testing

@testable import JevGateway

/// Settings' Test button: one cheap Jev call with the provider's saved key, through the same request path as a
/// Smart Paste, reported as "works" or the reason it does not.
@MainActor
@Suite struct JevConnectionTestTests {
    private static let answer = """
        {"answers":{"connection_test":{"type":"choice","choice":"ok","probabilities":{"ok":1}}}}
        """

    private static func test(
        _ provider: JevProvider = .vercelAIGateway,
        keys: [JevProvider: String] = [.vercelAIGateway: "fake-gateway-key", .typesafeDirect: "fake-typesafe-key"],
        transport: StubTransport
    ) async -> JevConnectionTestResult {
        // The chosen provider is the other one: Test checks the row's provider, whatever is chosen.
        let access = JevGatewayAccess(
            credentials: FakeJevCredentials(keys: keys), chosenProvider: { .vercelAIGateway }, transport: transport
        )
        return await withCheckedContinuation { continuation in
            access.testConnection(of: provider) { continuation.resume(returning: $0) }
        }
    }

    @Test func anAnsweredOneOptionChoiceWorks() async throws {
        let transport = StubTransport.answering(body: Self.answer)

        #expect(await Self.test(transport: transport) == .works)
        let sent = try #require(await transport.sentRequests.first)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer fake-gateway-key")
        #expect(await transport.sentRequests.count == 1)
    }

    @Test func withoutASavedKeyNothingIsSent() async {
        let transport = StubTransport.answering(body: Self.answer)

        #expect(await Self.test(keys: [:], transport: transport) == .failed(.noKey))
        #expect(await transport.sentRequests.isEmpty)
    }

    @Test(arguments: [
        (401, JevConnectionTestFailure.keyRejected(status: 401)), (403, .keyRejected(status: 403)),
        (429, .rateLimited), (500, .httpStatus(500)), (400, .httpStatus(400)),
    ])
    func anErrorStatusSaysWhatWentWrong(status: Int, failure: JevConnectionTestFailure) async {
        let transport = StubTransport.answering(status: status, body: #"{"error":{"type":"x"}}"#)

        #expect(await Self.test(transport: transport) == .failed(failure))
    }

    @Test func noResponseIsNoConnection() async {
        #expect(await Self.test(transport: StubTransport(.transportError)) == .failed(.noConnection))
    }

    @Test func anAnswerThatIsNotTheOfferedOptionIsUnexpected() async {
        let transport = StubTransport.answering(body: #"{"answers":{"connection_test":{"choice":"other"}}}"#)

        #expect(await Self.test(transport: transport) == .failed(.unexpectedAnswer))
    }

    @Test func typesafeDirectIsTestedThroughItsOwnEndpointWithItsOwnKey() async throws {
        let transport = StubTransport.answering(body: Self.answer)

        #expect(await Self.test(.typesafeDirect, transport: transport) == .works)
        let sent = try #require(await transport.sentRequests.first)
        #expect(sent.url?.absoluteString == "https://api.typesafe.ai/v1/systemone")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer fake-typesafe-key")
    }

    /// Typesafe direct answers a missing or unknown key with 403 and its auth error under `detail`.
    @Test(arguments: [
        (
            403, #"{"detail":{"error_type":"authentication_error","message":"Must supply an API key!"}}"#,
            JevConnectionTestResult.failed(.keyRejected(status: 403))
        ),
        (401, #"{"detail":{"error_type":"authentication_error"}}"#, .failed(.keyRejected(status: 401))),
        (422, #"{"detail":[{"loc":["body"],"msg":"x","type":"missing"}]}"#, .failed(.httpStatus(422))),
        (529, #"{"detail":{"error_type":"overloaded_error"}}"#, .failed(.rateLimited)),
    ])
    func typesafeDirectsErrorsSayWhatWentWrong(status: Int, body: String, result: JevConnectionTestResult) async {
        let transport = StubTransport.answering(status: status, body: body)

        #expect(await Self.test(.typesafeDirect, transport: transport) == result)
    }

    @Test func typesafeDirectWithoutASavedKeySendsNothing() async {
        let transport = StubTransport.answering(body: Self.answer)

        #expect(
            await Self.test(.typesafeDirect, keys: [.vercelAIGateway: "k"], transport: transport) == .failed(.noKey))
        #expect(await transport.sentRequests.isEmpty)
    }
}
