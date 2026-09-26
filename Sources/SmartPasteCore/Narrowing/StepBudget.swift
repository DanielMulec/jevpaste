/// The size budget of one Narrowing step (`cuts.Budget` in the spike): the tokens already committed — the state once,
/// and per question its instructions and fixed options — and what is left for the pieces.
struct StepBudget {
    let sizeModel: NarrowingSizeModel
    /// The estimated tokens of `state` (the copy and the Target Context).
    let stateTokens: Double
    /// The estimated tokens of one question before its pieces.
    let questionTokens: Double
    /// Pieces one choice can offer next to the three fixed options.
    let piecesPerChoice: Int

    /// Option tokens one choice can still take; zero or less when the copy alone is over the budget.
    var room: Double { sizeModel.questionBudget - stateTokens - questionTokens }

    /// Whether `pieces`, split into full-text choices, fit one request.
    func fits(_ pieces: [Substring]) -> Bool {
        let costs = pieces.map { sizeModel.optionTokens(of: $0) }
        guard room > 0, costs.allSatisfy({ $0 <= room }) else { return false }
        let choiceCount = Self.split(costs, size: piecesPerChoice, room: room, cost: { $0 }).count
        return stateTokens + Double(choiceCount) * questionTokens + costs.reduce(0, +) <= sizeModel.requestBudget
    }

    /// A quick lower bound before building pieces: can this many option tokens fit one request at all?
    func mightFit(optionTokens: Double) -> Bool {
        stateTokens + optionTokens <= sizeModel.requestBudget - questionTokens
    }

    /// `items` split in order into runs of at most `size`, and — when `room` is given — at most `room` tokens each.
    /// Never empty: no items give one empty run.
    static func split<Item>(_ items: [Item], size: Int, room: Double?, cost: (Item) -> Double) -> [[Item]] {
        var runs: [[Item]] = []
        var current: [Item] = []
        var used = 0.0
        for item in items {
            let itemCost = room == nil ? 0 : cost(item)
            if !current.isEmpty, current.count >= size || room.map({ used + itemCost > $0 }) == true {
                runs.append(current)
                current = []
                used = 0
            }
            current.append(item)
            used += itemCost
        }
        if !current.isEmpty { runs.append(current) }
        return runs.isEmpty ? [[]] : runs
    }
}
