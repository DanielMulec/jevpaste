import Foundation

extension Duration {
    /// This duration in seconds, as Foundation's `Timer` and `Date` take it.
    public var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
