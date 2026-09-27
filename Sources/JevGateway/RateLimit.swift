import Foundation

/// How long a rate limit (429) or an overload (Typesafe direct's 529) asks us to wait, from its headers.
enum RateLimit {
    /// The wait when no header gives one: one retry fits comfortably inside the Paste Attempt's 5 s clock.
    static let defaultRetryAfter: Duration = .seconds(1)
    /// Far beyond the Paste Attempt's 5 s clock; longer waits carry no more meaning and could overflow.
    static let longestRetryAfterSeconds: Double = 60

    /// `retry-after-ms` (milliseconds, TypeSafe's SDKs read it first), else `retry-after` (delta-seconds, whole or
    /// fractional), each finite and not negative, clamped to 60 s. Anything else — HTTP dates, NaN, infinities,
    /// negatives, words — is the default.
    static func retryAfter(of response: HTTPURLResponse) -> Duration {
        let milliseconds = number(in: response, header: "retry-after-ms").map { $0 / 1000 }
        guard let seconds = milliseconds ?? number(in: response, header: "retry-after") else {
            return defaultRetryAfter
        }
        let clampedSeconds = min(seconds, longestRetryAfterSeconds)
        return .milliseconds(Int((clampedSeconds * 1000).rounded()))
    }

    private static func number(in response: HTTPURLResponse, header: String) -> Double? {
        guard let value = response.value(forHTTPHeaderField: header),
            let number = Double(value.trimmingCharacters(in: .whitespaces)), number.isFinite, number >= 0
        else { return nil }
        return number
    }
}
