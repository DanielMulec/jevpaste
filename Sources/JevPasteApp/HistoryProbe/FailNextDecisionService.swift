// PROTOTYPE — history-probe, never merged
import SmartPasteCore
import os

/// PROBE-ONLY: wraps the real Jev decision service; when armed from the menu, the next request fails at once as if
/// Jev were unreachable ("Jev unavailable"), then it disarms. Lets Daniel see a failed attempt on demand.
final class FailNextDecisionService: DecisionService, Sendable {
    private let wrapped: any DecisionService
    private let armed = OSAllocatedUnfairLock(initialState: false)

    init(wrapping wrapped: any DecisionService) {
        self.wrapped = wrapped
    }

    var isArmed: Bool {
        armed.withLock { $0 }
    }

    func arm(_ value: Bool) {
        armed.withLock { $0 = value }
    }

    func requestDecision(
        _ request: DecisionRequest, reply: @escaping @MainActor @Sendable (DecisionReply) -> Void
    ) {
        let failNow = armed.withLock { state in
            defer { state = false }
            return state
        }
        guard failNow else { return wrapped.requestDecision(request, reply: reply) }
        Logger(subsystem: "jevpaste", category: "HistoryProbe").notice("probe: failing this Jev call on purpose")
        Task { @MainActor in reply(.failed) }
    }
}
