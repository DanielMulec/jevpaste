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
        keys: [JevProvider: String] = [.vercelAIGateway: "fake-gateway-key"], transport: StubTransport
    ) async -> JevConnectionTestResult {
        let access = JevGatewayAccess(
            credentials: FakeJevCredentials(keys: keys), chosenProvider: { .vercelAIGateway }, transport: transport
        )
        return await withCheckedContinuation { continuation in
            access.testConnection(of: .vercelAIGateway) { continuation.resume(returning: $0) }
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
}
