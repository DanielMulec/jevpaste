/// One line of the Active Item, without its line break.
struct SourceLine {
    /// The line without surrounding whitespace, a slice of the Active Item's text; empty for a blank line.
    let trimmed: Substring
    /// The number of leading whitespace `Character`s; a tab counts as one.
    let indentation: Int

    init(_ line: Substring) {
        trimmed = line.trimmingWhitespace
        indentation = line.prefix(while: \.isWhitespace).count
    }

    /// Empty or only whitespace.
    var isBlank: Bool { trimmed.isEmpty }
}

extension String {
    /// Every line of this text in document order, blank ones included.
    ///
    /// Every line is a slice of this string, so it is a byte-exact contiguous substring. `\r\n` is one
    /// `Character`, so a CRLF break never leaves a carriage return in a line.
    var sourceLines: [SourceLine] {
        split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(SourceLine.init)
    }
}

extension Substring {
    /// This slice without leading and trailing whitespace; the inside is untouched.
    var trimmingWhitespace: Substring {
        guard let first = firstIndex(where: { !$0.isWhitespace }),
            let last = lastIndex(where: { !$0.isWhitespace })
        else { return self[endIndex...] }
        return self[first...last]
    }
}
