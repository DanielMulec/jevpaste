extension Array where Element == SourceLine {
    /// The longest line that can be heading-like by its own shape (colon, upper case, short line).
    private static let maximumHeadingLength = 60
    /// The most words a short heading such as `Work History` may have.
    private static let maximumShortHeadingWords = 4

    /// Whether the line at `position` can lead a section. A labelled (`Label: value`) line never can. Otherwise
    /// any of: a Markdown heading; ends with `:`; upper case; followed by a deeper-indented line; a short line
    /// that starts a paragraph and has a next line. Rules: `docs/design/candidate-derivation.md`, rule 6.
    func isHeadingLike(at position: Int) -> Bool {
        let line = self[position].trimmed
        guard !line.isEmpty, line.labelledValue == nil else { return false }
        return line.isMarkdownHeading || line.isColonHeading || line.isUpperCaseHeading
            || isFollowedByDeeperIndentation(position) || isShortParagraphOpener(position)
    }

    private func isFollowedByDeeperIndentation(_ position: Int) -> Bool {
        guard let next = nonBlankLine(after: position) else { return false }
        return next.indentation > self[position].indentation
    }

    private func isShortParagraphOpener(_ position: Int) -> Bool {
        let line = self[position].trimmed
        let startsParagraph = position == startIndex || self[position - 1].isBlank
        return startsParagraph && nonBlankLine(after: position) != nil
            && line.count <= Self.maximumHeadingLength
            && line.split(whereSeparator: \.isWhitespace).count <= Self.maximumShortHeadingWords
            && !(line.last.map { ".,;".contains($0) } ?? false)
    }

    /// The line right after `position` when it exists and is not blank.
    private func nonBlankLine(after position: Int) -> SourceLine? {
        let next = position + 1
        return next < endIndex && !self[next].isBlank ? self[next] : nil
    }
}

extension Substring {
    fileprivate var isMarkdownHeading: Bool {
        wholeMatch(of: /#{1,6}[ \t].*/) != nil
    }

    fileprivate var isColonHeading: Bool {
        last == ":" && count <= 60
    }

    fileprivate var isUpperCaseHeading: Bool {
        filter(\.isLetter).count >= 2 && !contains(where: \.isLowercase) && count <= 60
    }
}
