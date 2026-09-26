import Foundation

/// Why a request ended in `NarrowingReply.failed`. Diagnostics only: carries no key, document, context or excerpt, so
/// it is safe to log.
enum JevGatewayFailure: Error, Equatable {
    /// The env file is missing, unreadable, or has no non-empty `AI_GATEWAY_API_KEY=` line. Carries no path: a path
    /// names the user's home directory.
    case missingKey
    case transport
    case httpStatus(Int)
    case malformedResponse
    /// Jev answered a question with an option id that question did not offer.
    case unknownChoice
}
