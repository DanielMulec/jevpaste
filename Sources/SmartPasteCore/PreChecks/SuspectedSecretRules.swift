/// The suspected-secret rules the Pre-checks apply, from "Choose clipboard-history storage and practical secret
/// protection": gitleaks-style prefix and format shapes, no entropy scan — plus, from "Refuse any copied API key at
/// ⌘⇧V, whatever its vendor", the whole-text Opaque Token, last so a named rule still names a match. Human-chosen
/// passwords without a recognisable shape slip through; detection is a visibility aid, never a guarantee.
public struct SuspectedSecretRules: Sendable {
    public let rules: [SuspectedSecretRule]

    /// The shapes found anywhere in a text. They screen the Target Context (surrounding text, window title).
    public static let anywhere = SuspectedSecretRules(rules: [
        .pemPrivateKey, .awsAccessKey, .gitHubToken, .slackToken, .stripeLiveKey, .stripeTestKey, .openAIStyleKey,
        .googleAPIKey, .vercelAIGatewayKey, .jsonWebToken, .connectionStringCredentials,
    ])

    /// What refuses an Active Item: every `anywhere` shape, then the Opaque Token. Item-only: a Target Context that
    /// is one bare token is sent unchanged.
    public static let standard = SuspectedSecretRules(rules: anywhere.rules + [.opaqueToken])

    /// The first rule, in order, whose shape occurs anywhere in `text`; `nil` when none does. Linear in the text.
    public func firstMatch(in text: String) -> SuspectedSecretRule? {
        let scanned = ScannedText(text)
        return rules.first { $0.matches(scanned) }
    }
}
