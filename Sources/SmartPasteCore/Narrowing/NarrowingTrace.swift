/// What Narrowing did in one Paste Attempt, for the diagnostic log only: numbers, never text.
public struct NarrowingTrace: Equatable, Sendable {
    public struct Step: Equatable, Sendable {
        /// The choice questions in the step's own request; 0 when a speculative answer decided it.
        public let questions: Int
        /// When the step needed a follow-up choice: how many speculative next-step questions rode along.
        public var followUpSpeculativeQuestions: Int?
        /// The step was answered by a speculative question of the previous follow-up, without a call.
        public let isSpeculative: Bool
        /// Jev's probability of the option the step's deciding choice picked; `nil` until it was answered.
        public var chosenProbability: Double?

        public init(
            questions: Int, followUpSpeculativeQuestions: Int?, isSpeculative: Bool, chosenProbability: Double? = nil
        ) {
            self.questions = questions
            self.followUpSpeculativeQuestions = followUpSpeculativeQuestions
            self.isSpeculative = isSpeculative
            self.chosenProbability = chosenProbability
        }
    }

    public var steps: [Step] = []
    /// Requests that used the full-text form.
    public var fullTextRequests = 0
    /// Jev's probability of the option that decided the outcome; `nil` until a choice decided.
    public var decidingProbability: Double?
    /// When Jev asked the user: how the Candidate Chooser's fill went; `nil` otherwise.
    public var chooserFill: ChooserFillTrace?

    public init(
        steps: [Step] = [], fullTextRequests: Int = 0, decidingProbability: Double? = nil,
        chooserFill: ChooserFillTrace? = nil
    ) {
        self.steps = steps
        self.fullTextRequests = fullTextRequests
        self.decidingProbability = decidingProbability
        self.chooserFill = chooserFill
    }

    /// The current step's deciding choice picked an option with probability `probability`.
    mutating func markChosen(probability: Double?) {
        decidingProbability = probability
        guard !steps.isEmpty else { return }
        steps[steps.count - 1].chosenProbability = probability
    }

    mutating func markFollowUp(speculativeQuestions: Int) {
        guard !steps.isEmpty else { return }
        steps[steps.count - 1].followUpSpeculativeQuestions = speculativeQuestions
    }
}

/// The Candidate Chooser's fill in one Paste Attempt, for the diagnostic log only.
public struct ChooserFillTrace: Equatable, Sendable {
    /// Fill choices sent (rate-limit retries not counted; `SmartPastePath.calls` counts every request).
    public var calls: Int
    /// Why the fill ended; `nil` while it runs.
    public var end: ChooserFillEnd?

    public init(calls: Int = 0, end: ChooserFillEnd? = nil) {
        self.calls = calls
        self.end = end
    }
}

/// Why the Candidate Chooser's fill ended.
public enum ChooserFillEnd: Equatable, Sendable {
    /// Jev kept the piece unchanged.
    case keep
    /// Jev found nothing (more) fits.
    case nothingFits
    /// The 5 s clock ran out.
    case clock
    /// The Gateway failed or refused the request.
    case failed
}
