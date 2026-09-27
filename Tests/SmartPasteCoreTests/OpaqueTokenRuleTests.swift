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

    /// Must not refuse: structured text, words and near misses. No rule of `standard` matches them at all.
    @Test(arguments: [
        "https://example.org/jevpaste/probe2026?id=42",
        "/tmp/jevpaste/probe-2026/notes.txt",
        "jev.probe2026@example.org",
        "+4915112345678",
        "2026-09-27",
        "JEVPASTEk3y1234",
        "Jevpaste",
        "Bildschirmfotografie",
        "JEVPASTE probe2026token",
        "JEVPASTE_TOKEN=probe0123456789abcdef",
        "Ada Lovelace\n12 Example Street\n10115 Berlin",
        #"{"name": "Ada", "id": "probe0123456789abc"}"#,
        "Please send the report2026 draft to the team by Friday.",
        "12345678901234567890",
        "JEVPASTEkey1234567\u{00A0}",
        "JEVPASTEkey1234567é",
    ])
    func leavesEverythingElseAlone(text: String) {
        #expect(!SuspectedSecretRule.opaqueToken.matches(text))
        #expect(SuspectedSecretRules.standard.firstMatch(in: text) == nil)
    }

    /// The whole text is the token: surrounding whitespace is trimmed, but the same token inside a sentence is not
    /// an Opaque Token.
    @Test(arguments: [
        ("  JEVPASTEk3y12345678\n", true),
        ("\tJEVPASTEk3y12345678\r\n", true),
        ("the key is JEVPASTEk3y12345678 today", false),
    ])
    func onlyTheWholeTrimmedTextCounts(text: String, matches: Bool) {
        #expect(SuspectedSecretRule.opaqueToken.matches(text) == matches)
    }

    @Test func sixteenBytesIsTheFloor() {
        #expect(SuspectedSecretRule.opaqueToken.matches("JEVPASTEk3y12345"))
        #expect(!SuspectedSecretRule.opaqueToken.matches("JEVPASTEk3y1234"))
    }
}

/// A digit is required (Gate A of "Refuse any copied API key at ⌘⇧V, whatever its vendor"): hyphenated or
/// snake_case words, identifiers and branch names are common copies and stay smart-pastable, so a key made only of
/// letters, `-` and `_` is an accepted miss. Pinned both ways so a change to it is deliberate.
struct OpaqueTokenTradeOffTests {
    @Test(arguments: [
        "feature-opaque-token",
        "maximum_retry_count",
        "Donaudampfschiffahrts-Gesellschaft",
        "JEVPASTE-keyabcd",
    ])
    func aTokenWithoutADigitIsNotAnOpaqueToken(text: String) {
        #expect(!SuspectedSecretRule.opaqueToken.matches(text))
    }
}
