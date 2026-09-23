/// The UTF-8 bytes of a text, with the few linear scans the suspected-secret rules are built from. Every rule
/// shape is ASCII, so bytes are enough and no scan ever decodes Unicode.
struct ScannedText {
    let bytes: [UInt8]

    init(_ text: String) {
        bytes = Array(text.utf8)
    }

    /// Every offset at which `pattern` starts. Linear in the text: patterns are short constants.
    func offsets(of pattern: [UInt8]) -> [Int] {
        guard let first = pattern.first, bytes.count >= pattern.count else { return [] }
        return bytes.withUnsafeBufferPointer { buffer in
            var found: [Int] = []
            for offset in 0...(buffer.count - pattern.count) where buffer[offset] == first {
                if hasPattern(pattern, at: offset) { found.append(offset) }
            }
            return found
        }
    }

    /// Whether `pattern` occurs at `offset`; `false` when it would run past the end.
    func hasPattern(_ pattern: [UInt8], at offset: Int) -> Bool {
        guard offset >= 0, offset + pattern.count <= bytes.count else { return false }
        var index = 0
        while index < pattern.count, bytes[offset + index] == pattern[index] {
            index += 1
        }
        return index == pattern.count
    }

    /// A token cannot start at `offset` when the byte before it continues a word: `xghp_…` is not a GitHub token.
    func startsToken(at offset: Int) -> Bool {
        offset == 0 || !ByteClass.tokenContinuation.contains(bytes[offset - 1])
    }

    /// The byte at `offset`, or `nil` past either end.
    func byte(at offset: Int) -> UInt8? {
        bytes.indices.contains(offset) ? bytes[offset] : nil
    }

    /// How many bytes from `offset` on belong to `byteClass`, counting at most `limit`, so a caller that only
    /// needs a minimum length never reads further than that.
    func run(of byteClass: ByteClass, from offset: Int, upTo limit: Int) -> Int {
        var length = 0
        while length < limit, offset + length < bytes.count, byteClass.contains(bytes[offset + length]) {
            length += 1
        }
        return length
    }
}

/// A set of ASCII bytes a secret's body is made of.
enum ByteClass {
    /// `A–Z`, `0–9`.
    case upperAlphanumerics
    /// `A–Z`, `a–z`, `0–9`.
    case alphanumerics
    /// Alphanumerics and `_`.
    case wordCharacters
    /// Alphanumerics and `-`.
    case alphanumericsAndHyphen
    /// The base64url alphabet: alphanumerics, `-` and `_`. Also what continues a token.
    case base64URL
    /// `A–Z` and space: a PEM header label such as `RSA PRIVATE KEY`.
    case pemLabel
    /// What may end a URL scheme: alphanumerics, `+`, `-`, `.`.
    case schemeCharacters
    /// Any byte of a URL authority: everything up to `/`, `?`, `#`, whitespace or a control byte.
    case authority

    static let tokenContinuation = ByteClass.base64URL

    func contains(_ byte: UInt8) -> Bool {
        switch self {
        case .upperAlphanumerics: byte.isUpperCaseLetter || byte.isDigit
        case .alphanumerics: byte.isAlphanumeric
        case .wordCharacters: byte.isAlphanumeric || byte == UInt8(ascii: "_")
        case .alphanumericsAndHyphen: byte.isAlphanumeric || byte == UInt8(ascii: "-")
        case .base64URL: byte.isAlphanumeric || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "_")
        case .pemLabel: byte.isUpperCaseLetter || byte == UInt8(ascii: " ")
        case .schemeCharacters:
            byte.isAlphanumeric || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ".")
        case .authority:
            byte > UInt8(ascii: " ") && byte != 0x7F && byte != UInt8(ascii: "/") && byte != UInt8(ascii: "?")
                && byte != UInt8(ascii: "#")
        }
    }
}

extension UInt8 {
    fileprivate var isUpperCaseLetter: Bool { (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(self) }
    fileprivate var isDigit: Bool { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self) }
    fileprivate var isAlphanumeric: Bool {
        isUpperCaseLetter || isDigit || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(self)
    }
}
