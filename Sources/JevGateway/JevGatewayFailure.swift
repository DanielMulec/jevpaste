import Foundation

/// Why a request ended in `DecisionReply.failed`. Diagnostics only: carries no key, document, context or
/// Candidate, so it is safe to log.
enum JevGatewayFailure: Error, Equatable {
    /// The env file is missing, unreadable, or has no non-empty `AI_GATEWAY_API_KEY=` line.
    case missingKey(file: String)
    /// More Candidates than Jev's option limit allows next to `none_of_these`.
    case tooManyCandidates(count: Int)
    /// The request body could not be encoded.
    case malformedRequest
    case transport
    case httpStatus(Int)
    case malformedResponse
    /// Jev answered with an option id that was not offered.
    case unknownChoice
}
