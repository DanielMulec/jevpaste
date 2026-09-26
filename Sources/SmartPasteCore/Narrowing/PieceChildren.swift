/// The pieces offered next to a piece unchanged: its coarse children and its fine runs (`children2` in the spike's
/// `r2.py`, over `cuts.py`), each deduplicated by bytes, the piece itself never among them.
///
/// Coarse children alone reach every substring that starts and ends on a non-whitespace character (see
/// `NarrowingReachabilityTests`); fine runs only group short runs early, and are left out when they would not fit.
struct PieceChildren {
    let coarse: [Substring]
    let fine: [Substring]

    var all: [Substring] { coarse + fine }

    init(of piece: Substring, policy: NarrowingPolicy, budget: StepBudget) {
        let coarse = Self.coarse(of: piece, budget: budget).deduplicated(excluding: piece)
        let fineLimit = policy.maximumQuestionsPerStep * policy.piecesPerChoice - coarse.count
        let fine = Self.fineRuns(of: piece, tokenLimit: policy.fineRunTokenLimit)
            .newTexts(besides: [piece] + coarse, atMost: fineLimit)
        self.coarse = coarse
        self.fine = fine.map { $0.isEmpty || !budget.fits(coarse + $0) ? [] : $0 } ?? []
    }

    /// Several lines → runs of lines + edge cuts; one line of several tokens → runs of tokens + edge cuts; one token
    /// → the token without its outer whitespace, or every substring of it; one character → nothing.
    private static func coarse(of piece: Substring, budget: StepBudget) -> [Substring] {
        let lines = PieceCutting.lines(of: piece)
        if lines.count >= 2 {
            return grouped(lines, in: piece, extra: PieceCutting.edgeCuts(of: piece), budget: budget)
        }
        let tokens = PieceCutting.tokens(of: piece)
        if tokens.count >= 2 {
            return grouped(tokens, in: piece, extra: PieceCutting.edgeCuts(of: piece), budget: budget)
        }
        guard let token = tokens.first else { return [] }
        if !token.utf8.elementsEqual(piece.utf8) { return [token] }
        let characters = token.indices.map { token[$0...$0] }
        return grouped(characters, in: token, extra: [], budget: budget)
    }

    /// Every run of 1…`tokenLimit` consecutive tokens inside one line.
    private static func fineRuns(of piece: Substring, tokenLimit: Int) -> [Substring] {
        PieceCutting.lines(of: piece).flatMap { line in
            let tokens = PieceCutting.tokens(of: line)
            return tokens.indices.flatMap { first in
                let lastAllowed = min(tokens.count, first + tokenLimit) - 1
                return (first...lastAllowed).reversed().map { last in
                    piece[tokens[first].startIndex..<tokens[last].endIndex]
                }
            }
        }
    }

    /// Every run of `units` plus `extra`, if that fits the budget; else runs of blocks of b consecutive units (the
    /// smallest b that fits) plus every single unit (plus `extra` when it still fits); else the single units.
    private static func grouped(
        _ units: [Substring], in piece: Substring, extra: [Substring], budget: StepBudget
    ) -> [Substring] {
        let estimate = RunSizeEstimate(of: units, in: piece, sizeModel: budget.sizeModel)
        if budget.mightFit(optionTokens: estimate.ofEveryRun(ofBlocksOf: 1)) {
            let pieces = (PieceCutting.runs(of: units, in: piece) + extra).deduplicated(excluding: piece)
            if budget.fits(pieces) { return pieces }
        }
        guard units.count >= 2 else { return units.deduplicated(excluding: piece) }
        let singlesTokens = units.reduce(0) { $0 + budget.sizeModel.optionTokens(of: $1) }
        for blockSize in 2...units.count
        where budget.mightFit(optionTokens: estimate.ofEveryRun(ofBlocksOf: blockSize) + singlesTokens) {
            let blocks = stride(from: 0, to: units.count, by: blockSize).map { start in
                piece[units[start].startIndex..<units[min(start + blockSize, units.count) - 1].endIndex]
            }
            for withExtra in [true, false] {
                let pieces = (PieceCutting.runs(of: blocks, in: piece) + units + (withExtra ? extra : []))
                    .deduplicated(excluding: piece)
                if budget.fits(pieces) { return pieces }
            }
        }
        return units.deduplicated(excluding: piece)
    }
}

/// A quick estimate of what every run of a piece's units — or of blocks of them — would cost as options, without
/// building the runs: their total length at the piece's token density, plus the per-option tokens.
private struct RunSizeEstimate {
    let tokensPerScalar: Double
    let tokensPerOption: Double
    /// Each unit's start and end in Unicode scalars from the piece's start.
    let bounds: [(start: Int, end: Int)]

    init(of units: [Substring], in piece: Substring, sizeModel: NarrowingSizeModel) {
        tokensPerScalar = sizeModel.estimatedTokens(of: piece) / Double(max(1, piece.unicodeScalars.count))
        tokensPerOption = sizeModel.tokensPerOption
        let scalars = piece.unicodeScalars
        var position = scalars.startIndex
        var offset = 0
        bounds = units.map { unit in
            offset += scalars.distance(from: position, to: unit.startIndex)
            let start = offset
            offset += scalars.distance(from: unit.startIndex, to: unit.endIndex)
            position = unit.endIndex
            return (start, offset)
        }
    }

    /// The estimate for every run of blocks of `blockSize` consecutive units (1: of the units themselves).
    func ofEveryRun(ofBlocksOf blockSize: Int) -> Double {
        let blocks = stride(from: 0, to: bounds.count, by: blockSize).map { first in
            (start: bounds[first].start, end: bounds[min(first + blockSize, bounds.count) - 1].end)
        }
        let count = blocks.count
        let ends = blocks.enumerated().reduce(0) { $0 + $1.element.end * ($1.offset + 1) }
        let starts = blocks.enumerated().reduce(0) { $0 + $1.element.start * (count - $1.offset) }
        return Double(ends - starts) * tokensPerScalar + tokensPerOption * Double(count * (count + 1)) / 2
    }
}
