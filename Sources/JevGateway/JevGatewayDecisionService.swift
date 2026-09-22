import SmartPasteCore

/// The `DecisionService` adapter that will ask Jev through the Vercel AI Gateway.
///
/// Scaffold only: no network calls yet.
public struct JevGatewayDecisionService: DecisionService {
    public init() {}

    public func requestDecision(
        _ request: DecisionRequest,
        reply: @escaping @MainActor @Sendable (DecisionReply) -> Void
    ) {}
}
