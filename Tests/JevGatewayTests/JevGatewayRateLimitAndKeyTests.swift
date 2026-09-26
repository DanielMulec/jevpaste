import Foundation
import SmartPasteCore
import Testing

@testable import JevGateway

private let rateLimitBody = #"{"error":{"type":"rate_limit_exceeded"}}"#

private func reply(to429WithHeaders headers: [String: String]) async throws -> NarrowingReply {
    let transport = StubTransport.answering(status: 429, headers: headers, body: rateLimitBody)
    return await reply(from: Fixture.service(transport: transport))
}

@Suite struct JevGatewayRateLimitTests {
    @Test func retryAfterInWholeSecondsIsPassedOn() async throws {
        #expect(try await reply(to429WithHeaders: ["Retry-After": "7"]) == .rateLimited(retryAfter: .seconds(7)))
    }

    @Test func retryAfterInFractionalSecondsIsPassedOn() async throws {
        let decisionReply = try await reply(to429WithHeaders: ["retry-after": "1.5"])
        #expect(decisionReply == .rateLimited(retryAfter: .milliseconds(1500)))
    }

    @Test(arguments: [
        [:], ["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"], ["Retry-After": "-3"],
        ["Retry-After": "nan"], ["Retry-After": "inf"], ["Retry-After": "-inf"], ["Retry-After": "-1e20"],
    ])
    func aMissingOrUnusableRetryAfterWaitsOneSecond(headers: [String: String]) async throws {
        #expect(try await reply(to429WithHeaders: headers) == .rateLimited(retryAfter: .seconds(1)))
    }

    @Test(arguments: ["61", "1e20", "1e308"])
    func aRetryAfterBeyondSixtySecondsIsClampedToSixtySeconds(header: String) async throws {
        #expect(try await reply(to429WithHeaders: ["Retry-After": header]) == .rateLimited(retryAfter: .seconds(60)))
    }

    @Test func aRetryAfterOfExactlySixtySecondsIsPassedOn() async throws {
        #expect(try await reply(to429WithHeaders: ["Retry-After": "60"]) == .rateLimited(retryAfter: .seconds(60)))
    }
}

/// The env file is only the one-time import source for the Keychain; these pin how it is read.
@Suite struct GatewayEnvFileTests {
    @Test func aMissingKeyFileHasNoKey() {
        let missingFile = FileManager.default.temporaryDirectory.appending(path: "absent-\(UUID().uuidString).env")
        #expect(GatewayCredentials(envFile: missingFile).apiKey() == nil)
    }

    @Test(arguments: ["", "OTHER_KEY=value\n", "AI_GATEWAY_API_KEY=\n", "AI_GATEWAY_API_KEY=  \n"])
    func aKeyFileWithoutAKeyHasNoKey(keyFileText: String) throws {
        #expect(GatewayCredentials(envFile: try Fixture.keyFile(containing: keyFileText)).apiKey() == nil)
    }

    @Test(arguments: [
        "AI_GATEWAY_API_KEY=test-key-value",
        "# comment\nOTHER=1\nAI_GATEWAY_API_KEY=test-key-value\n",
        "export AI_GATEWAY_API_KEY=test-key-value\n",
        "AI_GATEWAY_API_KEY=\"test-key-value\"\n",
        "AI_GATEWAY_API_KEY='test-key-value'\n",
    ])
    func theKeyIsReadFromShellStyleAssignments(keyFileText: String) throws {
        let credentials = GatewayCredentials(envFile: try Fixture.keyFile(containing: keyFileText))
        #expect(credentials.apiKey() == "test-key-value")
    }

    @Test func theDefaultKeyFileIsTheJevpasteEnvFile() {
        let expected = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/jevpaste/env")
        #expect(GatewayCredentials.standard.envFile.standardizedFileURL == expected.standardizedFileURL)
    }
}
