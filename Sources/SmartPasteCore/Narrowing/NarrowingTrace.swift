/// What Narrowing did in one Paste Attempt, for the diagnostic log only: numbers, never text.
public struct NarrowingTrace: Equatable, Sendable {
    public struct Step: Equatable, Sendable {
        /// The choice questions in the step's own request; 0 when a speculative answer decided it.
        public let questions: Int
        /// When the step needed a follow-up choice: how many speculative next-step questions rode along.
        public var followUpSpeculativeQuestions: Int?
        /// The step was answered by a speculative question of the previous follow-up, without a call.
        public let isSpeculative: Bool

        public init(questions: Int, followUpSpeculativeQuestions: Int?, isSpeculative: Bool) {
            self.questions = questions
            self.followUpSpeculativeQuestions = followUpSpeculativeQuestions
            self.isSpeculative = isSpeculative
        }
    }

    public var steps: [Step] = []
    /// Requests that used the full-text form.
    public var fullTextRequests = 0
    /// Jev's probability of the option that decided the outcome; `nil` until a choice decided.
    public var decidingProbability: Double?

    public init(steps: [Step] = [], fullTextRequests: Int = 0, decidingProbability: Double? = nil) {
        self.steps = steps
        self.fullTextRequests = fullTextRequests
        self.decidingProbability = decidingProbability
    }

    mutating func markFollowUp(speculativeQuestions: Int) {
        guard !steps.isEmpty else { return }
        steps[steps.count - 1].followUpSpeculativeQuestions = speculativeQuestions
    }
}
