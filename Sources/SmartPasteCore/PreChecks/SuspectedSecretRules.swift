/// The suspected-secret rules the Pre-checks apply, from "Choose clipboard-history storage and practical secret
/// protection": gitleaks-style prefix and format shapes, no entropy scan. Human-chosen passwords without a
/// recognisable shape slip through; detection is a visibility aid, never a guarantee.
public struct SuspectedSecretRules: Sendable {
    public let rules: [SuspectedSecretRule]

    public static let standard = SuspectedSecretRules(rules: [
        .pemPrivateKey, .awsAccessKey, .gitHubToken, .slackToken, .stripeLiveKey, .openAIStyleKey, .googleAPIKey,
        .jsonWebToken, .connectionStringCredentials,
    ])

    /// The first rule, in order, whose shape occurs anywhere in `text`; `nil` when none does. Linear in the text.
    public func firstMatch(in text: String) -> SuspectedSecretRule? {
        let scanned = ScannedText(text)
        return rules.first { $0.matches(scanned) }
    }
}
