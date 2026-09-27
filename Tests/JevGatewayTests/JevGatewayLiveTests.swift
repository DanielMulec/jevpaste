import Foundation
import JevGateway
import Testing

@testable import SmartPasteCore

/// One real Narrowing step through Jev, only with `JEVPASTE_LIVE_JEV=1` and a key in `~/.config/jevpaste/env`;
/// otherwise skipped, so `make check` stays offline.
@Suite struct JevGatewayLiveTests {
    private static let isEnabled =
        ProcessInfo.processInfo.environment["JEVPASTE_LIVE_JEV"] == "1" && GatewayCredentials.standard.hasAPIKey

    @Test(.enabled(if: isEnabled, "set JEVPASTE_LIVE_JEV=1 and provide ~/.config/jevpaste/env"))
    func oneRealStepPicksAPieceHoldingTheEmailForAnEmailField() async throws {
        let copy = "Name: Grace Example\nEmail: grace@example.test\nCity: Springfield"
        let context = TargetContext(
            fieldLabel: "Email address", placeholder: "you@example.com", sectionHeading: "Contact details",
            siblingFieldLabels: ["Full name", "City"]
        )
        let request = StepPlanner(copy: copy, context: context, policy: .r2b).stepRequest(on: copy[...]).request
        let started = ContinuousClock.now
        let apiKey = try #require(GatewayCredentials.standard.apiKey())
        let narrowingReply = await reply(from: JevGatewayDecisionService(apiKey: apiKey), to: request)
        let latency = ContinuousClock.now - started
        FileHandle.standardError.write(Data("[live-jev] \(narrowingReply); wall-clock latency \(latency)\n".utf8))

        guard case .answered(let answers) = narrowingReply, let answer = answers["narrow_0"] else {
            Issue.record("expected an answer, got \(narrowingReply)")
            return
        }
        let chosenText = request.excerpts.first { $0.id == answer.choice }?.text ?? ""
        #expect(chosenText.contains("grace@example.test"))
    }
}
