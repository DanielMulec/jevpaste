/// When Jev asks the user, Jev fills the Candidate Chooser too, row by row (live finding F1, 2026-09-26; Daniel's
/// decision). Jev's probabilities do not list every candidate: with two addresses, the one written first took all the
/// weight `ask_user` left and the other got 0 in every run. So the deciding choice is asked again in the fill wording,
/// without `ask_user` and without every piece that overlaps a row found so far; each pick is the next row, until Jev
/// keeps the piece or finds nothing (more) fits. No local number ends the list; the 5 s clock bounds it.
struct ChooserFill {
    /// The choice that asked the user; every fill choice is it, narrowed.
    let deciding: PlannedQuestion
    /// Jev's picks so far, in the order found.
    private(set) var rows: [Substring] = []

    mutating func add(row: Substring) {
        rows.append(row)
    }

    /// The next fill choice, and the excerpts its ids name in the excerpt-id form. Ids, option order and texts are the
    /// deciding choice's; left out are `ask_user` and every piece with an occurrence in the current piece that
    /// overlaps an occurrence of a row — a text that occurs twice is one option, so either place excludes it.
    func nextQuestion(wordings: NarrowingWordings) -> (question: PlannedQuestion, excerpts: [NarrowingExcerpt]) {
        let current = deciding.currentPiece
        let options = deciding.question.options
        let pieces = options.map { option -> Substring? in
            guard case .piece(let text) = deciding.meanings[option.id] else { return nil }
            return text
        }
        let overlapping = RowOverlap.of(pieces.map { $0 ?? "" }, withRows: rows, in: current)
        var kept: [ChoiceOption] = []
        var meanings: [String: OptionMeaning] = [:]
        var excerpts: [NarrowingExcerpt] = []
        for (index, option) in options.enumerated() {
            guard let meaning = deciding.meanings[option.id], meaning != .askUser, !overlapping[index] else { continue }
            kept.append(option)
            meanings[option.id] = meaning
            if deciding.form == .excerptIDs, let text = excerptText(of: meaning) {
                excerpts.append(NarrowingExcerpt(id: option.id, text: String(text)))
            }
        }
        let question = ChoiceQuestion(
            id: deciding.question.id, instructions: instructions(wordings), options: kept)
        let planned = PlannedQuestion(
            question: question, currentPiece: current, form: deciding.form, meanings: meanings)
        return (planned, excerpts)
    }

    /// The deciding choice's instructions with its fill wording: the step's wording without the `ask_user` sentence.
    private func instructions(_ wordings: NarrowingWordings) -> ChoiceQuestion.Instructions {
        let isExcerptIDs = deciding.form == .excerptIDs
        switch deciding.question.instructions {
        case .wholeCopy:
            return .wholeCopy(isExcerptIDs ? wordings.firstStepFillWithExcerptIDs : wordings.firstStepFillWithFullText)
        case .onPiece(let currentPiece, _):
            let question = isExcerptIDs ? wordings.laterStepFillWithExcerptIDs : wordings.laterStepFillWithFullText
            return .onPiece(currentPiece: currentPiece, question: question)
        }
    }

    /// The text an excerpt id names: a piece, or — at a later step — the unchanged current piece, whose option is its
    /// own excerpt id.
    private func excerptText(of meaning: OptionMeaning) -> Substring? {
        switch meaning {
        case .piece(let text): return text
        case .unchanged:
            guard case .onPiece = deciding.question.instructions else { return nil }
            return deciding.currentPiece
        case .nothingFits, .askUser: return nil
        }
    }
}

/// Which texts overlap a row of the Candidate Chooser, by UTF-8 byte ranges in the current piece: a text overlaps
/// when any of its occurrences overlaps any occurrence of a row.
enum RowOverlap {
    /// For each of `texts`, whether it overlaps a row; `false` for an empty text.
    static func of(_ texts: [Substring], withRows rows: [Substring], in piece: Substring) -> [Bool] {
        let haystack = Array(piece.utf8)
        let rowSpans = rows.flatMap { row in
            occurrences(of: Array(row.utf8), in: haystack).map { $0..<$0 + row.utf8.count }
        }
        var overlaps = [Bool](repeating: false, count: texts.count)
        let byLength = Dictionary(grouping: texts.indices) { texts[$0].utf8.count }
        for (length, indices) in byLength where length > 0 && length <= haystack.count {
            let needles = indices.map { Array(texts[$0].utf8) }
            let table = RollingHash.table(of: needles)
            for span in rowSpans {
                // Windows starting here reach into the span: start > span.lowerBound - length, start < upperBound.
                let first = max(0, span.lowerBound - length + 1)
                let last = min(span.upperBound - 1, haystack.count - length)
                guard first <= last else { continue }
                RollingHash.windows(of: length, in: haystack, starting: first...last) { offset, hash in
                    for position in table[hash] ?? [] where !overlaps[indices[position]] {
                        let window = haystack[offset..<offset + length]
                        overlaps[indices[position]] = window.elementsEqual(needles[position])
                    }
                    return true
                }
            }
        }
        return overlaps
    }

    /// Every offset where `needle` occurs in `haystack`, overlapping occurrences included.
    private static func occurrences(of needle: [UInt8], in haystack: [UInt8]) -> [Int] {
        guard !needle.isEmpty, needle.count <= haystack.count else { return [] }
        let target = RollingHash.of(needle[...])
        let length = needle.count
        var starts: [Int] = []
        RollingHash.windows(of: length, in: haystack, starting: 0...(haystack.count - length)) { offset, hash in
            if hash == target, haystack[offset..<offset + length].elementsEqual(needle) { starts.append(offset) }
            return true
        }
        return starts
    }
}
