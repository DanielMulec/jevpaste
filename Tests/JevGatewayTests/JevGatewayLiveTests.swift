import Foundation
import JevGateway
import Testing

@testable import SmartPasteCore

/// One real Narrowing step through each Jev Provider, only with `JEVPASTE_LIVE_JEV=1` and that provider's key file;
/// otherwise skipped, so `make check` stays offline.
@Suite struct JevGatewayLiveTests {
    @Test(.enabled(if: LiveJev.isEnabled(for: .vercelAIGateway), "JEVPASTE_LIVE_JEV=1 and a Gateway key file"))
    func throughTheGatewayOneRealStepPicksAPieceHoldingTheEmail() async throws {
        try await expectOneRealStepPicksAPieceHoldingTheEmail(through: .vercelAIGateway)
    }

    @Test(.enabled(if: LiveJev.isEnabled(for: .typesafeDirect), "JEVPASTE_LIVE_JEV=1 and a Typesafe key file"))
    func throughTypesafeDirectOneRealStepPicksAPieceHoldingTheEmail() async throws {
        try await expectOneRealStepPicksAPieceHoldingTheEmail(through: .typesafeDirect)
    }

    private func expectOneRealStepPicksAPieceHoldingTheEmail(through provider: JevProvider) async throws {
        let request = LiveCard.stepOneRequest
        let started = ContinuousClock.now
        let narrowingReply = await reply(from: try LiveJev.service(for: provider), to: request)
        let latency = LiveJev.milliseconds(.now - started)
        guard case .answered(let answers) = narrowingReply, let answer = answers["narrow_0"] else {
            LiveJev.report("live-jev", "provider=\(provider.rawValue) reply=\(narrowingReply) latency_ms=\(latency)")
            Issue.record("expected an answer, got \(narrowingReply)")
            return
        }
        let chosenText = request.excerpts.first { $0.id == answer.choice }?.text ?? ""
        let probability = answer.probabilities.first { $0.optionID == answer.choice }?.probability ?? -1
        LiveJev.report(
            "live-jev",
            "provider=\(provider.rawValue) choice=\(answer.choice) p=\(probability) latency_ms=\(latency)"
        )
        #expect(chosenText.contains("grace@example.test"))
    }
}

/// A synthetic contact card and an email field — the live tests' one fixed step.
enum LiveCard {
    static let stepOneRequest: NarrowingRequest = {
        let copy = "Name: Grace Example\nEmail: grace@example.test\nCity: Springfield"
        let context = TargetContext(
            fieldLabel: "Email address", placeholder: "you@example.com", sectionHeading: "Contact details",
            siblingFieldLabels: ["Full name", "City"]
        )
        return StepPlanner(copy: copy, context: context, policy: .r2b).stepRequest(on: copy[...]).request
    }()
}
