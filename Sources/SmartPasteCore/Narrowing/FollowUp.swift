/// A choice question and Jev's answer to it, ranked: the most likely option first, ties in the order Jev listed them.
struct AnsweredChoice {
    let planned: PlannedQuestion
    let answer: ChoiceAnswer

    /// What the chosen option means; `nil` when Jev chose an id this question never offered.
    var chosen: OptionMeaning? { planned.meanings[answer.choice] }

    var chosenProbability: Double? {
        answer.probabilities.first { $0.optionID == answer.choice }?.probability
    }

    /// Every offered option with its probability, the most likely first; ids the question never offered are dropped.
    var ranked: [(meaning: OptionMeaning, probability: Double)] {
        let known = answer.probabilities.compactMap { option in
            planned.meanings[option.optionID].map { (meaning: $0, probability: option.probability) }
        }
        return known.enumerated()
            .sorted {
                $0.element.probability != $1.element.probability
                    ? $0.element.probability > $1.element.probability : $0.offset < $1.offset
            }
            .map(\.element)
    }
}

/// The step's several choices answered: whether they agree, and what a follow-up choice would carry.
struct ChoicesOfOneStep {
    let answered: [AnsweredChoice]

    /// The option every choice picked, when that is the same keep, nothing-fits or ask-the-user option: the step's
    /// answer without a follow-up. `nil` when any picked a piece or they differ.
    var agreedAnswer: AnsweredChoice? {
        let picks = answered.map(\.chosen)
        guard let first = picks.first, let meaning = first, meaning.isFixedOption,
            picks.allSatisfy({ $0 == meaning })
        else { return nil }
        return answered.first
    }

    /// Every piece with at least `threshold` in any choice, the most likely first (ties: first carried first), each
    /// at its highest probability.
    func carriedPieces(threshold: Double) -> [(piece: Substring, probability: Double)] {
        var order: [ExactText] = []
        var best: [ExactText: (piece: Substring, probability: Double)] = [:]
        for choice in answered {
            for (meaning, probability) in choice.ranked where probability >= threshold {
                guard case .piece(let text) = meaning else { continue }
                let key = ExactText(text)
                if let known = best[key] {
                    if probability > known.probability { best[key] = (text, probability) }
                } else {
                    order.append(key)
                    best[key] = (text, probability)
                }
            }
        }
        let carried = order.compactMap { best[$0] }
        return carried.enumerated()
            .sorted {
                $0.element.probability != $1.element.probability
                    ? $0.element.probability > $1.element.probability : $0.offset < $1.offset
            }
            .map(\.element)
    }
}

extension OptionMeaning {
    /// Keep, nothing fits or ask the user: not a piece.
    var isFixedOption: Bool {
        if case .piece = self { return false }
        return true
    }
}
