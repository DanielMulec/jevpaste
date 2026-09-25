/// What a Paste Attempt asks Jev: which Candidate of the source document belongs in the Target.
public struct DecisionRequest: Equatable, Sendable {
    /// The pinned Active Item's full text; document order carries meaning, so it is always sent.
    public let sourceDocument: String
    public let targetContext: TargetContext
    public let candidates: [Candidate]

    public init(sourceDocument: String, targetContext: TargetContext, candidates: [Candidate]) {
        self.sourceDocument = sourceDocument
        self.targetContext = targetContext
        self.candidates = candidates
    }
}

/// Jev's typed answer to a `DecisionRequest`. Never text: a choice, the no-match gate and the free-text judgement.
public struct Decision: Equatable, Sendable {
    public enum Choice: Equatable, Sendable {
        case candidate(Candidate)
        case noneOfThese
    }

    public let choice: Choice
    /// Probability that the source document contains a value for the Target; below 0.5 means No Suitable Match.
    public let containsValueProbability: Double
    /// Probability that the Target is a Free-text Target; at or above 0.8 the whole Active Item is pasted.
    public let freeTextProbability: Double

    public init(choice: Choice, containsValueProbability: Double, freeTextProbability: Double = 0) {
        self.choice = choice
        self.containsValueProbability = containsValueProbability
        self.freeTextProbability = freeTextProbability
    }
}

/// How a `DecisionService` answers one request.
public enum DecisionReply: Equatable, Sendable {
    case decided(Decision)
    /// The service asked us to wait (HTTP 429 with `retry-after`); the Paste Attempt decides whether to retry.
    case rateLimited(retryAfter: Duration)
    /// The service could not be reached or answered with an error.
    case failed
}
