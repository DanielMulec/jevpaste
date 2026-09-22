extension Array where Element == SourceLine {
    /// Each line, and the value of each `Label: value` line, in document order.
    var singleLineExcerpts: [Excerpt] {
        filter { !$0.isBlank }.flatMap { line -> [Excerpt] in
            guard let value = line.trimmed.labelledValue else { return [Excerpt(text: line.trimmed, kind: .plainLine)] }
            return [Excerpt(text: line.trimmed, kind: .wholeLabelledLine), Excerpt(text: value, kind: .labelValue)]
        }
    }

    /// Paragraphs, heading-led sections and the whole item, wherever they span two or more non-blank lines.
    var multiLineExcerpts: [Excerpt] {
        paragraphs.map { Excerpt(spanning: $0, kind: .paragraph) }
            + sections.map { Excerpt(spanning: $0, kind: .section) }
            + wholeItem
    }

    /// Each heading-like line with its body.
    private var sections: [ArraySlice<SourceLine>] {
        indices.filter(isHeadingLike(at:)).compactMap(section(ledBy:))
    }

    /// The body starts with the next line, which must be non-blank, and always includes it; it ends before the
    /// first later line that is blank, heading-like, or indented less than the first body line.
    private func section(ledBy heading: Int) -> ArraySlice<SourceLine>? {
        let firstBody = heading + 1
        guard firstBody < endIndex, !self[firstBody].isBlank else { return nil }
        let end = self[(firstBody + 1)...].indices.first { !continuesBody(at: $0, startedAt: firstBody) } ?? endIndex
        return self[heading..<end]
    }

    private func continuesBody(at position: Int, startedAt firstBody: Int) -> Bool {
        !self[position].isBlank && !isHeadingLike(at: position)
            && self[position].indentation >= self[firstBody].indentation
    }

    /// The whole item from its first to its last non-blank line, when those differ.
    private var wholeItem: [Excerpt] {
        let nonBlankLines = filter { !$0.isBlank }
        guard nonBlankLines.count >= 2 else { return [] }
        return [Excerpt(spanning: nonBlankLines, kind: .wholeItem)]
    }

    /// Maximal runs of two or more consecutive non-blank lines.
    private var paragraphs: [ArraySlice<SourceLine>] {
        split(whereSeparator: \.isBlank).filter { $0.count >= 2 }
    }
}
