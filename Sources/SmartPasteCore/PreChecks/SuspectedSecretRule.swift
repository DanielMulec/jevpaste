/// One recognisable shape of a secret, matched anywhere in a text: a visibility aid, never a guarantee.
///
/// Every rule scans in linear time without regular expressions, so an arbitrarily large Active Item cannot hang
/// a Paste Attempt.
public struct SuspectedSecretRule: Sendable {
    /// Names the rule in tests and diagnostic logs; never the matched text.
    public let name: String
    private let isFound: @Sendable (ScannedText) -> Bool

    init(name: String, isFound: @escaping @Sendable (ScannedText) -> Bool) {
        self.name = name
        self.isFound = isFound
    }

    /// Whether `text` contains this shape anywhere.
    public func matches(_ text: String) -> Bool {
        isFound(ScannedText(text))
    }

    func matches(_ text: ScannedText) -> Bool {
        isFound(text)
    }

    /// A rule for tokens that start with a known prefix, at a token boundary, followed by at least
    /// `minimumBodyLength` bytes of `body`. Reads at most that many bytes after each prefix.
    static func prefixedToken(
        named name: String, prefixes: [String], body: ByteClass, minimumBodyLength: Int
    ) -> SuspectedSecretRule {
        let patterns = prefixes.map { Array($0.utf8) }
        return SuspectedSecretRule(name: name) { text in
            patterns.contains { pattern in
                text.offsets(of: pattern).contains { offset in
                    text.startsToken(at: offset)
                        && text.run(of: body, from: offset + pattern.count, upTo: minimumBodyLength)
                            == minimumBodyLength
                }
            }
        }
    }
}

extension SuspectedSecretRule {
    /// GitHub classic personal access tokens (`ghp_` + 36) and fine-grained ones (`github_pat_` + 82).
    public static let gitHubToken = SuspectedSecretRule(name: "gitHubToken") { text in
        classicGitHubToken.matches(text) || fineGrainedGitHubToken.matches(text)
    }

    private static let classicGitHubToken = prefixedToken(
        named: "gitHubToken", prefixes: ["ghp_"], body: .alphanumerics, minimumBodyLength: 36
    )
    private static let fineGrainedGitHubToken = prefixedToken(
        named: "gitHubToken", prefixes: ["github_pat_"], body: .wordCharacters, minimumBodyLength: 82
    )
}

extension SuspectedSecretRule {
    /// AWS access key ids: `AKIA` + 16 upper-case alphanumerics.
    public static let awsAccessKey = prefixedToken(
        named: "awsAccessKey", prefixes: ["AKIA"], body: .upperAlphanumerics, minimumBodyLength: 16
    )
    /// Slack tokens: `xoxb-`, `xoxa-`, `xoxp-`, `xoxr-`, `xoxs-` + at least 10 alphanumerics or hyphens.
    public static let slackToken = prefixedToken(
        named: "slackToken", prefixes: ["xoxb-", "xoxa-", "xoxp-", "xoxr-", "xoxs-"],
        body: .alphanumericsAndHyphen, minimumBodyLength: 10
    )
    /// Stripe live secret keys: `sk_live_` + at least 16 alphanumerics.
    public static let stripeLiveKey = prefixedToken(
        named: "stripeLiveKey", prefixes: ["sk_live_"], body: .alphanumerics, minimumBodyLength: 16
    )
    /// OpenAI- and Anthropic-style keys: `sk-` + at least 20 base64url bytes. The broadest shape, so the token
    /// boundary matters most here: `task-…` or `desk-…` never start one.
    public static let openAIStyleKey = prefixedToken(
        named: "openAIStyleKey", prefixes: ["sk-"], body: .base64URL, minimumBodyLength: 20
    )
    /// Google API keys: `AIza` + 35 base64url bytes.
    public static let googleAPIKey = prefixedToken(
        named: "googleAPIKey", prefixes: ["AIza"], body: .base64URL, minimumBodyLength: 35
    )
}
