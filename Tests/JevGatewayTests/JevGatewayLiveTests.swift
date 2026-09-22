import Foundation
import JevGateway
import SmartPasteCore
import Testing

/// One real call to Jev, only with `JEVPASTE_LIVE_JEV=1` and a key in `~/.config/jevpaste/env`; otherwise
/// skipped, so `make check` stays offline. The free tier allows about one call per second account-wide.
@Suite struct JevGatewayLiveTests {
    private static let isEnabled =
        ProcessInfo.processInfo.environment["JEVPASTE_LIVE_JEV"] == "1" && GatewayCredentials.standard.hasAPIKey

    @Test(.enabled(if: isEnabled, "set JEVPASTE_LIVE_JEV=1 and provide ~/.config/jevpaste/env"))
    func oneRealCallChoosesTheEmailForAnEmailField() async {
        let email = Candidate(text: "grace@example.test")
        let request = DecisionRequest(
            sourceDocument: "Name: Grace Example\nEmail: grace@example.test\nCity: Springfield",
            targetContext: TargetContext(
                fieldLabel: "Email address",
                placeholder: "you@example.com",
                sectionHeading: "Contact details",
                siblingFieldLabels: ["Full name", "City"]
            ),
            candidates: [Candidate(text: "Grace Example"), email, Candidate(text: "Springfield")]
        )
        let started = ContinuousClock.now
        let decisionReply = await reply(from: JevGatewayDecisionService(), to: request)
        let latency = ContinuousClock.now - started

        let outcome: String
        switch decisionReply {
        case .decided(let decision):
            let chose = decision.choice == .candidate(email) ? "the email Candidate" : "another option"
            outcome = "decided, chose \(chose), containsValueProbability \(decision.containsValueProbability)"
        case .rateLimited(let retryAfter): outcome = "rate limited, retry after \(retryAfter)"
        case .failed: outcome = "failed"
        }
        let milliseconds = latency.components.seconds * 1000 + latency.components.attoseconds / 1_000_000_000_000_000
        FileHandle.standardError.write(Data("[live-jev] \(outcome); wall-clock latency \(milliseconds) ms\n".utf8))

        guard case .decided(let decision) = decisionReply else {
            Issue.record("expected a decision, got \(outcome)")
            return
        }
        #expect(decision.choice == .candidate(email))
        #expect(decision.containsValueProbability >= 0.5)
    }
}
