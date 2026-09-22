import Foundation

/// How long an HTTP 429 asks us to wait, from its `retry-after` header.
enum RateLimit {
    /// The free tier allows about one call per second, so that is the wait when the header gives none.
    static let defaultRetryAfter: Duration = .seconds(1)

    /// Delta-seconds (whole or fractional, not negative); anything else, HTTP dates included, is the default.
    static func retryAfter(of response: HTTPURLResponse) -> Duration {
        guard
            let header = response.value(forHTTPHeaderField: "retry-after"),
            let seconds = Double(header.trimmingCharacters(in: .whitespaces)),
            seconds.isFinite, seconds >= 0
        else { return defaultRetryAfter }
        return .milliseconds(Int((seconds * 1000).rounded()))
    }
}
