import Foundation

/// How long an HTTP 429 asks us to wait, from its `retry-after` header.
enum RateLimit {
    /// The free tier allows about one call per second, so that is the wait when the header gives none.
    static let defaultRetryAfter: Duration = .seconds(1)
    /// Far beyond the Paste Attempt's 5 s clock; longer waits carry no more meaning and could overflow.
    static let longestRetryAfterSeconds: Double = 60

    /// Delta-seconds (whole or fractional, not negative), clamped to 60 s. Anything else — HTTP dates, NaN,
    /// infinities, negatives — is the default.
    static func retryAfter(of response: HTTPURLResponse) -> Duration {
        guard
            let header = response.value(forHTTPHeaderField: "retry-after"),
            let seconds = Double(header.trimmingCharacters(in: .whitespaces)),
            seconds.isFinite, seconds >= 0
        else { return defaultRetryAfter }
        let clampedSeconds = min(seconds, longestRetryAfterSeconds)
        return .milliseconds(Int((clampedSeconds * 1000).rounded()))
    }
}
