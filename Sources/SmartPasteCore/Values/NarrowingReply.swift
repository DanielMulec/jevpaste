/// How a `DecisionService` answers one `NarrowingRequest`.
public enum NarrowingReply: Equatable, Sendable {
    /// Jev's answer to every question, by question id.
    case answered([String: ChoiceAnswer])
    /// The service asked us to wait (HTTP 429 with `retry-after`); the Paste Attempt decides whether to retry.
    case rateLimited(retryAfter: Duration)
    /// Jev refused the request's size (HTTP 400 `max_tokens_exceeded`): the copy is too long for one call.
    case tooLarge
    /// The service could not be reached or answered with an error.
    case failed
}

/// Jev's typed answer to one choice question. Never text: an option id and the probability of every option.
public struct ChoiceAnswer: Equatable, Sendable {
    /// The option id Jev chose.
    public let choice: String
    /// Every option's probability, in the order Jev listed them (which breaks ties between equal probabilities).
    public let probabilities: [OptionProbability]

    public init(choice: String, probabilities: [OptionProbability]) {
        self.choice = choice
        self.probabilities = probabilities
    }
}

public struct OptionProbability: Equatable, Sendable {
    public let optionID: String
    public let probability: Double

    public init(optionID: String, probability: Double) {
        self.optionID = optionID
        self.probability = probability
    }
}
