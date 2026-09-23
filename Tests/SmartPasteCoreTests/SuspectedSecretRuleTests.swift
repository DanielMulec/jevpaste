import SmartPasteCore
import Testing

/// Each suspected-secret rule on its own: the shapes it must catch inside ordinary text, and near misses it must
/// leave alone. All secrets here are synthetic.
struct SuspectedSecretRuleTests {
    @Test(arguments: [
        "ghp_JEVPASTE0000000000000000000000000000",
        "token: ghp_aB3dE5fG7hI9jK1lM3nO5pQ7rS9tU1vW3xY5 (rotate me)",
        "github_pat_" + String(repeating: "A1_b", count: 21),
    ])
    func gitHubTokenMatches(text: String) {
        #expect(SuspectedSecretRule.gitHubToken.matches(text))
    }

    @Test(arguments: [
        "ghp_short123",
        "see the ghp_ prefix in the docs",
        "xghp_JEVPASTE0000000000000000000000000000",
        "github_pat_" + String(repeating: "A", count: 40),
    ])
    func gitHubTokenIgnores(text: String) {
        #expect(!SuspectedSecretRule.gitHubToken.matches(text))
    }
}

/// The single-prefix token rules: the shape, then near misses (too short, wrong prefix, no token boundary).
struct PrefixedTokenRuleTests {
    @Test(arguments: [
        (SuspectedSecretRule.awsAccessKey, "aws_access_key_id = AKIAJEVPASTE0EXAMPLE"),
        (.slackToken, "SLACK_BOT_TOKEN=xoxb-2026000000-jevpaste-probe"),
        (.slackToken, "xoxp-1234567890-abc"),
        (.stripeLiveKey, "sk_live_JEVPASTE00000000EXAMPLE"),
        (.openAIStyleKey, "OPENAI_API_KEY=sk-proj-JEVPASTE000000000000000000"),
        (.openAIStyleKey, "sk-ant-api03-JEVPASTE_00000000000000"),
        (.googleAPIKey, "key=AIzaJEVPASTE000000000000000000000000000"),
    ])
    func matches(rule: SuspectedSecretRule, text: String) {
        #expect(rule.matches(text), "\(rule.name)")
    }

    @Test(arguments: [
        (SuspectedSecretRule.awsAccessKey, "AKIA0SHORT"),
        (.awsAccessKey, "akiajevpaste0example00"),
        (.awsAccessKey, "XAKIAJEVPASTE0EXAMPLE"),
        (.slackToken, "xoxz-2026000000-jevpaste-probe"),
        (.slackToken, "xoxb-short"),
        (.stripeLiveKey, "sk_test_JEVPASTE00000000EXAMPLE"),
        (.openAIStyleKey, "sk-short"),
        (.openAIStyleKey, "Open task-list-2026-09-24-follow-up-items-for-review"),
        (.openAIStyleKey, "https://example.org/blog/risk-assessment-for-desk-workers-2026"),
        (.openAIStyleKey, "a whisk-and-bowl-recipe-collection-for-beginners"),
        (.googleAPIKey, "AIzaShortKey"),
    ])
    func ignores(rule: SuspectedSecretRule, text: String) {
        #expect(!rule.matches(text), "\(rule.name)")
    }
}

/// `openAIStyleKey` favours recall over precision, per "Choose clipboard-history storage and practical secret
/// protection": detection is a visibility aid, never a guarantee. A standalone `sk-` slug of 20+ characters looks
/// exactly like a key, so it is blocked — an accepted false positive, pinned here so a change to it is deliberate.
struct OpenAIStyleKeyTradeOffTests {
    @Test(arguments: [
        "See sk-2026-09-24-release-notes-for-team",
        "https://example.org/docs/sk-2026-09-24-release-notes-for-team",
    ])
    func aStandaloneSkSlugIsAnAcceptedFalsePositive(text: String) {
        #expect(SuspectedSecretRule.openAIStyleKey.matches(text))
    }
}
