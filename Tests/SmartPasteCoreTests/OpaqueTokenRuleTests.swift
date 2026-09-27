import SmartPasteCore
import Testing

/// The Opaque Token rule against the corpus of "Refuse any copied API key at ⌘⇧V, whatever its vendor": a whole
/// Active Item that is one token of letters and digits is a Suspected Secret, whatever its prefix. Every token
/// here is synthetic or a well-known sample value.
struct OpaqueTokenRuleTests {
    /// Must refuse, as the whole item. Each case names the rule `standard` reports first.
    @Test(arguments: [
        ("ts_JEVPASTE" + String(repeating: "x9Y8", count: 6), "opaqueToken"),
        ("d41d8cd98f00b204e9800998ecf8427e", "opaqueToken"),
        ("da39a3ee5e6b4b0d3255bfef95601890afd80709", "opaqueToken"),
        ("123e4567-e89b-12d3-a456-426614174000", "opaqueToken"),
        ("JEVPASTE_k3y-0123456789a", "opaqueToken"),
        ("JEVP4-ASTE0-XMPL7-K3", "opaqueToken"),
        ("DE89370400440532013000", "opaqueToken"),
    ])
    func refusesAWholeItemToken(text: String, firstRuleName: String) {
        #expect(SuspectedSecretRule.opaqueToken.matches(text))
        #expect(SuspectedSecretRules.standard.firstMatch(in: text)?.name == firstRuleName)
    }
}
