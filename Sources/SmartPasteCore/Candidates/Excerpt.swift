/// One would-be Candidate: a slice of the Active Item plus the kind of structure it came from.
struct Excerpt {
    enum Kind {
        /// A line that is not a `Label: value` line.
        case plainLine
        /// The whole of a `Label: value` line; its value is a separate excerpt.
        case wholeLabelledLine
        /// The value of a `Label: value` line.
        case labelValue
        /// A run of two or more consecutive non-blank lines.
        case paragraph
        /// A heading-like line and the lines of its body.
        case section
        /// The whole Active Item, from its first to its last non-blank line.
        case wholeItem

        /// When the cap bites, kinds with a lower rank go first; `nil` kinds are only cut from the document end.
        var dropRank: Int? {
            switch self {
            case .wholeItem: 0
            case .section: 1
            case .paragraph: 2
            case .wholeLabelledLine: 3
            case .plainLine, .labelValue: nil
            }
        }
    }

    let text: Substring
    let kind: Kind

    /// The excerpt from the first non-whitespace character of `lines`' first line to the end of its last line.
    /// Both must be non-blank; the slice is taken from the Active Item's text, so everything between stays.
    init(spanning lines: some BidirectionalCollection<SourceLine>, kind: Kind) {
        let first = lines.first?.trimmed ?? ""
        let last = lines.last?.trimmed ?? first
        text = first.base[first.startIndex..<last.endIndex]
        self.kind = kind
    }

    init(text: Substring, kind: Kind) {
        self.text = text
        self.kind = kind
    }
}

extension Array where Element == Excerpt {
    /// These excerpts in document order: by start; at the same start the longer first (container before
    /// contents); at the same range the kind dropped last first, so deduplication keeps that one.
    func inDocumentOrder() -> [Excerpt] {
        sorted { left, right in
            if left.text.startIndex != right.text.startIndex { return left.text.startIndex < right.text.startIndex }
            if left.text.endIndex != right.text.endIndex { return left.text.endIndex > right.text.endIndex }
            return (left.kind.dropRank ?? .max) > (right.kind.dropRank ?? .max)
        }
    }

    /// These excerpts without any whose UTF-8 bytes equal an earlier one's. Byte comparison, not `String`
    /// equality, so canonically equivalent but differently encoded texts both stay.
    func removingRepeatedText() -> [Excerpt] {
        var seen: Set<[UInt8]> = []
        return filter { seen.insert([UInt8]($0.text.utf8)).inserted }
    }
}
