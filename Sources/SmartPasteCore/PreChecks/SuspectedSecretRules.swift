/// The suspected-secret rules the Pre-checks apply, from "Choose clipboard-history storage and practical secret
/// protection": gitleaks-style prefix and format shapes, no entropy scan — plus, from "Refuse any copied API key at
/// ⌘⇧V, whatever its vendor", the whole-text Opaque Token, last so a named rule still names a match. Human-chosen
/// passwords without a recognisable shape slip through; detection is a visibility aid, never a guarantee.
public struct SuspectedSecretRules: Sendable {
    public let rules: [SuspectedSecretRule]

    public static let standard = SuspectedSecretRules(rules: [
        .pemPrivateKey, .awsAccessKey, .gitHubToken, .slackToken, .stripeLiveKey, .openAIStyleKey, .googleAPIKey,
        .jsonWebToken, .connectionStringCredentials, .opaqueToken,
    ])

    /// The first rule, in order, whose shape occurs anywhere in `text`; `nil` when none does. Linear in the text.
    public func firstMatch(in text: String) -> SuspectedSecretRule? {
        let scanned = ScannedText(text)
        return rules.first { $0.matches(scanned) }
    }
}
