/// The rules whose shape is more than a prefix. Each scan starts only at a fixed marker or a token start and stops
/// at the first byte outside its shape, so every byte is read a bounded number of times: linear time.
extension SuspectedSecretRule {
    /// A PEM private-key header on one line: `-----BEGIN ` + an upper-case label ending in `PRIVATE KEY` +
    /// `-----` (`RSA`, `EC`, `OPENSSH`, `ENCRYPTED` or none). Public keys and certificates do not match.
    public static let pemPrivateKey = SuspectedSecretRule(name: "pemPrivateKey") { text in
        text.offsets(of: pemHeaderStart).contains { offset in
            let labelStart = offset + pemHeaderStart.count
            let labelLength = text.run(of: .pemLabel, from: labelStart, upTo: longestPEMLabel)
            let label = text.bytes[labelStart..<labelStart + labelLength]
            return label.reversed().starts(with: pemPrivateKeyLabel.reversed())
                && text.hasPattern(pemDashes, at: labelStart + labelLength)
        }
    }

    /// A JSON Web Token: three `.`-separated base64url segments of at least 10 bytes, the first two (header and
    /// payload, both JSON objects) starting with `eyJ`, at a token start.
    public static let jsonWebToken = SuspectedSecretRule(name: "jsonWebToken") { text in
        text.offsets(of: jsonObjectStart).contains { offset in
            guard text.startsToken(at: offset) else { return false }
            let header = text.run(of: .base64URL, from: offset, upTo: .max)
            let payloadStart = offset + header + 1
            guard header >= minimumJWTSegment, text.byte(at: payloadStart - 1) == dot,
                text.hasPattern(jsonObjectStart, at: payloadStart)
            else { return false }
            let payload = text.run(of: .base64URL, from: payloadStart, upTo: .max)
            let signatureStart = payloadStart + payload + 1
            return payload >= minimumJWTSegment && text.byte(at: signatureStart - 1) == dot
                && text.run(of: .base64URL, from: signatureStart, upTo: minimumJWTSegment) == minimumJWTSegment
        }
    }

    /// A URL-style connection string with an inline password: `scheme://user:password@host`, where the password
    /// is not empty (the user may be, as in `redis://:password@host`). Only the authority is read — up to the
    /// first `/`, `?`, `#` or whitespace — so `https://host/users/a@b` does not match.
    public static let connectionStringCredentials = SuspectedSecretRule(name: "connectionStringCredentials") { text in
        text.offsets(of: schemeSeparator).contains { offset in
            guard offset > 0, ByteClass.schemeCharacters.contains(text.bytes[offset - 1]) else { return false }
            let authorityStart = offset + schemeSeparator.count
            let authorityLength = text.run(of: .authority, from: authorityStart, upTo: .max)
            let authority = text.bytes[authorityStart..<authorityStart + authorityLength]
            guard let userInfoEnd = authority.firstIndex(of: atSign),
                let passwordStart = authority[..<userInfoEnd].firstIndex(of: colon)
            else { return false }
            return passwordStart + 1 < userInfoEnd
        }
    }

    private static let pemHeaderStart = Array("-----BEGIN ".utf8)
    private static let pemPrivateKeyLabel = Array("PRIVATE KEY".utf8)
    private static let pemDashes = Array("-----".utf8)
    /// `ENCRYPTED PRIVATE KEY` and `OPENSSH PRIVATE KEY` are 21 and 19 bytes; a longer label is not a header.
    private static let longestPEMLabel = 40
    private static let jsonObjectStart = Array("eyJ".utf8)
    private static let minimumJWTSegment = 10
    private static let schemeSeparator = Array("://".utf8)
    private static let dot = UInt8(ascii: ".")
    private static let colon = UInt8(ascii: ":")
    private static let atSign = UInt8(ascii: "@")
}
