import Testing

@testable import SmartPasteCore

/// No piece is ever unreachable: every substring that starts and ends on a non-whitespace character can be reached by
/// a path of choices, each step choosing one of the offered children. Ported from the spike's `cuts.self_check`
/// (exhaustive over its sample texts) and `r2.py reach` (every expected excerpt of every cell that fits one request),
/// plus every line, token and run of up to three tokens of every spike copy.
struct NarrowingReachabilityTests {
    /// The spike's `self_check` samples, plus CRLF, a decomposed letter and an emoji, and copies with outer line
    /// breaks, whose text without them is reached by keeping the whole copy, never offered as a piece.
    static let samples = [
        "Mira Holzner\nPrankergasse77\n\n8020 Graz.", "a@b.c d\ne-f g\nx", "Innsbruck. Hi",
        "ab-cd ef\n\ngh ij.k\nl m", "Zu\u{308}rich 8020\r\nTop 11 👍🏽", "\nMira Holzner\n8020 Graz\n",
        "Innsbruck. Hi\r\n",
    ]

    @Test(arguments: samples)
    func everySubstringOfASampleIsReachable(sample: String) {
        let reachability = Reachability(copy: sample)

        let unreachable = sample.nonWhitespaceBoundedSubstrings.filter { !reachability.reaches($0) }

        #expect(unreachable.isEmpty, "unreachable: \(unreachable)")
    }

    @Test func everyExpectedExcerptOfEverySpikeCellIsReachable() {
        #expect(NarrowingCell.all.count == 82)
        for cell in NarrowingCell.all {
            let reachability = Reachability(copy: cell.item)
            for target in cell.targets {
                let occurrence = cell.item[...].firstOccurrence(of: target[...])
                #expect(occurrence.map(reachability.reaches) == true, "\(cell.id): \(target)")
            }
        }
    }

    @Test func everyLineTokenAndShortTokenRunOfEverySpikeCopyIsReachable() {
        let copies = Set(NarrowingCell.all.map(\.item)).sorted()
        for copy in copies {
            let reachability = Reachability(copy: copy)
            let lines = PieceCutting.lines(of: copy[...])
            let targets =
                lines
                + lines.flatMap { line in
                    let tokens = PieceCutting.tokens(of: line)
                    return tokens.indices.flatMap { first in
                        (first..<min(tokens.count, first + 3)).map {
                            line[tokens[first].startIndex..<tokens[$0].endIndex]
                        }
                    }
                }
            let unreachable = targets.filter { !reachability.reaches($0) }
            #expect(unreachable.isEmpty, "\(unreachable.prefix(5))")
        }
    }
}

/// Searches a path of offered children from the whole copy down to a target, following only children that contain
/// it (at its own position first, then anywhere), the smallest first.
private final class Reachability {
    private let copy: String
    private let policy = NarrowingPolicy.r2b
    /// By the piece's range in the copy: equal texts at other places are cut again, which is cheap and exact.
    private var childrenByRange: [Range<String.Index>: [Substring]] = [:]

    init(copy: String) {
        self.copy = copy
    }

    func reaches(_ target: Substring) -> Bool {
        if target.utf8.elementsEqual(OuterLineBreaks.stripped(from: copy).utf8) { return true }  // keep at step 1
        var visited: Set<Range<String.Index>> = []
        return search(from: copy[...], to: target, visited: &visited)
    }

    private func search(from piece: Substring, to target: Substring, visited: inout Set<Range<String.Index>>) -> Bool {
        if piece.utf8.elementsEqual(target.utf8) { return true }
        guard visited.insert(piece.startIndex..<piece.endIndex).inserted else { return false }
        let children = children(of: piece)
        let containing = children.filter { $0.startIndex <= target.startIndex && target.endIndex <= $0.endIndex }
        if !containing.isEmpty {
            return containing.contains { search(from: $0, to: target, visited: &visited) }
        }
        return children.contains { child in
            guard let occurrence = child.firstOccurrence(of: target) else { return false }
            return search(from: child, to: occurrence, visited: &visited)
        }
    }

    /// What a step on `piece` offers, the smallest first, with the spike's step budget (state ≈ the copy, 250 + 900
    /// tokens per question, plus `current_piece` after step 1).
    private func children(of piece: Substring) -> [Substring] {
        let range = piece.startIndex..<piece.endIndex
        if let known = childrenByRange[range] { return known }
        let sizeModel = policy.sizeModel
        let isFirstStep = piece.utf8.elementsEqual(copy.utf8)
        let budget = StepBudget(
            sizeModel: sizeModel, stateTokens: sizeModel.estimatedTokens(of: copy),
            questionTokens: 1150 + (isFirstStep ? 0 : sizeModel.estimatedTokens(of: piece)),
            piecesPerChoice: policy.piecesPerChoice
        )
        let pastedWhenKept = isFirstStep ? Substring(OuterLineBreaks.stripped(from: copy)) : nil
        let children = PieceChildren(of: piece, pastedWhenKept: pastedWhenKept, policy: policy, budget: budget).all
            .sorted {
                $0.utf8.count < $1.utf8.count
            }
        childrenByRange[range] = children
        return children
    }
}

extension Substring {
    /// The first slice of this text whose UTF-8 bytes equal `target`'s.
    fileprivate func firstOccurrence(of target: Substring) -> Substring? {
        utf8.firstRange(of: target.utf8).map { self[$0] }
    }
}

extension String {
    /// Every substring that starts and ends on a non-whitespace character.
    fileprivate var nonWhitespaceBoundedSubstrings: [Substring] {
        indices.filter { !self[$0].isWhitespace }.flatMap { start in
            indices[start...].filter { !self[$0].isWhitespace }.map { self[start...$0] }
        }
    }
}
