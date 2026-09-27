extension SuspectedSecretRule {
    /// An Opaque Token: the *whole* text, trimmed of surrounding whitespace, is one token of at least 16 bytes made
    /// only of letters, digits, `-` and `_`, with at least one letter and at least one digit — the shape of a copied
    /// API key, whatever its vendor.
    ///
    /// Unlike every other rule this is a whole-text shape, not one found anywhere: a key inside a sentence is left
    /// to the prefix rules. Whitespace, `.`, `/`, `@`, `:` and non-ASCII bytes are outside the token's bytes, so
    /// URLs, paths, emails, times and structured text never match. One pass: the first foreign byte ends the scan.
    public static let opaqueToken = SuspectedSecretRule(name: "opaqueToken") { text in
        let token = text.trimmingWhitespace()
        guard token.count >= minimumOpaqueTokenLength else { return false }
        var hasLetter = false
        var hasDigit = false
        for byte in token {
            if ByteClass.letters.contains(byte) {
                hasLetter = true
            } else if ByteClass.digits.contains(byte) {
                hasDigit = true
            } else if !ByteClass.base64URL.contains(byte) {
                return false
            }
        }
        return hasLetter && hasDigit
    }

    private static let minimumOpaqueTokenLength = 16
}
