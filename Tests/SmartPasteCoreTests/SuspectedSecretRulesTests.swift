import SmartPasteCore
import Testing

/// The standard set of suspected-secret rules as the Pre-checks use it.
struct SuspectedSecretRulesTests {
    @Test func standardSetHoldsTheDecidedRulesWithOpaqueTokenLast() {
        #expect(
            SuspectedSecretRules.standard.rules.map(\.name) == [
                "pemPrivateKey", "awsAccessKey", "gitHubToken", "slackToken", "stripeLiveKey", "stripeTestKey",
                "openAIStyleKey", "googleAPIKey", "vercelAIGatewayKey", "jsonWebToken", "connectionStringCredentials",
                "opaqueToken",
            ]
        )
    }

    @Test func theTargetContextIsScreenedByEveryRuleButTheOpaqueToken() {
        #expect(
            SuspectedSecretRules.anywhere.rules.map(\.name)
                == SuspectedSecretRules.standard.rules.dropLast().map(\.name))
        #expect(SuspectedSecretRules.standard.rules.last?.name == "opaqueToken")
    }

    @Test func ordinaryContentMatchesNoRule() {
        let text = """
            Name: Ada Lovelace
            Email: ada@example.com
            Website: https://ada.example.org:8443/notes?page=2#top
            Phone: +44 20 7946 0958
            Notes: ask about the task-list-2026-09-24 and the desk-booking-system-rollout.
            """

        #expect(SuspectedSecretRules.standard.firstMatch(in: text) == nil)
    }

    @Test func firstMatchNamesTheRuleForASecretInsideOrdinaryText() {
        let text = "Hi Ada,\nthe staging key is AKIAJEVPASTE0EXAMPLE — please rotate it.\nThanks"

        #expect(SuspectedSecretRules.standard.firstMatch(in: text)?.name == "awsAccessKey")
    }
}

/// Linear-time proof: inputs built to make a backtracking or rescanning matcher quadratic (every position a
/// prefix hit or a token start). 256 KB each. Measured in a debug build: 0.1–0.5 s each run serially, up to 0.8 s
/// under parallel tests. A quadratic scan reads ~10¹⁰ bytes here and takes minutes. The 5 s bound is loose on
/// purpose, so a loaded machine running `make check` cannot make it flake, while a quadratic regression still
/// fails by more than an order of magnitude.
struct SuspectedSecretLinearTimeTests {
    static let size = 256 * 1024

    /// Each argument is repeated to 256 KB inside the test, so test output names only the repeated unit.
    @Test(arguments: ["sk-", "eyJ.", "eyJ", "a://", "-----BEGIN ", "ghp_", "xoxb-", "AKIA", "a:@", "a://b:"])
    func adversarialInputFinishesInLinearTime(repeatedUnit: String) {
        let text = String(repeating: repeatedUnit, count: Self.size / repeatedUnit.utf8.count)
        let clock = ContinuousClock()

        let elapsed = clock.measure {
            _ = SuspectedSecretRules.standard.firstMatch(in: text)
        }

        #expect(elapsed < .seconds(5))
    }

    /// The Opaque Token reads the whole text: one 256 KB token is refused, and the same token with one space in the
    /// middle is not a token at all — the scan stops at the space.
    @Test(arguments: [(false, "opaqueToken"), (true, nil)] as [(Bool, String?)])
    func aWholeTextTokenFinishesInLinearTime(spaceInTheMiddle: Bool, firstRuleName: String?) {
        let half = String(repeating: "a1", count: Self.size / 4)
        let text = half + (spaceInTheMiddle ? " " : "") + half
        let clock = ContinuousClock()
        var found: SuspectedSecretRule?

        let elapsed = clock.measure {
            found = SuspectedSecretRules.standard.firstMatch(in: text)
        }

        #expect(found?.name == firstRuleName)
        #expect(elapsed < .seconds(5))
    }
}
