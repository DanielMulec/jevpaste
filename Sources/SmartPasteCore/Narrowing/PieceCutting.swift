/// The scissors of Narrowing: where a piece can be cut, by character classes only — never by what the text means.
///
/// Three kinds of cut point, coarse to fine: line breaks (lines), spaces and punctuation (tokens), and characters.
/// Every result is a `Substring` of its input and so of the Active Item: an exact slice by index range, byte for
/// byte. Ported from `cuts.py` (spike `spike/narrowing` @ ba32886), with Swift `Character`s (grapheme clusters) where
/// Python used code points, so no cut ever splits a grapheme.
enum PieceCutting {
    /// Runs of consecutive non-blank text between line breaks, outer whitespace trimmed. A CRLF pair is one break.
    static func lines(of piece: Substring) -> [Substring] {
        piece.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(\.trimmingWhitespace)
            .filter { !$0.isEmpty }
    }

    /// Maximal runs of letters and numbers, and every other non-whitespace `Character` on its own.
    static func tokens(of text: Substring) -> [Substring] {
        var tokens: [Substring] = []
        var position = text.startIndex
        while position < text.endIndex {
            let character = text[position]
            if character.isWhitespace {
                position = text.index(after: position)
            } else if character.isLetterOrNumber {
                let end = text[position...].firstIndex { !$0.isLetterOrNumber } ?? text.endIndex
                tokens.append(text[position..<end])
                position = end
            } else {
                let end = text.index(after: position)
                tokens.append(text[position..<end])
                position = end
            }
        }
        return tokens
    }

    /// Every contiguous run of `units` (slices of `piece`, in order): by start, the longer first.
    static func runs(of units: [Substring], in piece: Substring) -> [Substring] {
        units.indices.flatMap { first in
            units.indices[first...].reversed().map { last in piece[units[first].startIndex..<units[last].endIndex] }
        }
    }

    /// The cuts that reach substrings starting or ending inside a token, or inside a line across a line break.
    /// One line: every cut at a character inside its first token (from the left) and its last token (from the
    /// right). Several lines: without the first token, the first character, the last token, the last character.
    static func edgeCuts(of piece: Substring) -> [Substring] {
        let pieceLines = lines(of: piece)
        guard let firstLine = pieceLines.first, let lastLine = pieceLines.last,
            let firstToken = tokens(of: firstLine).first, let lastToken = tokens(of: lastLine).last
        else { return [] }
        let text = piece[firstLine.startIndex..<lastLine.endIndex]
        guard pieceLines.count >= 2 else {
            return characterCuts(inside: firstToken, keepingTo: text.endIndex, of: text)
                + characterCuts(inside: lastToken, keepingFrom: text.startIndex, of: text)
        }
        let firstTokens = tokens(of: firstLine)
        let lastTokens = tokens(of: lastLine)
        let afterFirstToken = firstTokens.count > 1 ? firstTokens[1].startIndex : firstToken.endIndex
        let beforeLastToken = lastTokens.count > 1 ? lastTokens[lastTokens.count - 2].endIndex : lastToken.startIndex
        return [
            text[afterFirstToken...], text[text.index(after: text.startIndex)...],
            text[..<beforeLastToken], text[..<text.index(before: text.endIndex)],
        ].map(\.trimmingWhitespace)
    }

    /// `text` from each character boundary strictly inside `token` to `end`, left to right.
    private static func characterCuts(
        inside token: Substring, keepingTo end: Substring.Index, of text: Substring
    ) -> [Substring] {
        token.indices.dropFirst().map { text[$0..<end] }
    }

    /// `text` from `start` to each character boundary strictly inside `token`, right to left.
    private static func characterCuts(
        inside token: Substring, keepingFrom start: Substring.Index, of text: Substring
    ) -> [Substring] {
        token.indices.dropFirst().reversed().map { text[start..<$0] }
    }
}

extension Character {
    /// A letter or a number (Python's `str.isalnum`, per grapheme cluster).
    var isLetterOrNumber: Bool { isLetter || isNumber }
}

extension Substring {
    /// This slice without leading and trailing whitespace (line breaks included); the inside is untouched.
    var trimmingWhitespace: Substring {
        guard let first = firstIndex(where: { !$0.isWhitespace }),
            let last = lastIndex(where: { !$0.isWhitespace })
        else { return self[endIndex...] }
        return self[first...last]
    }
}
