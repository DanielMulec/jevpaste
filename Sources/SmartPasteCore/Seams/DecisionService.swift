/// Asks Jev one Narrowing request: which option of each choice question belongs at the Bound Target.
///
/// The seam between the Paste Attempt and the remote decision. The real adapter lives in `JevGateway`; tests supply an
/// in-memory fake. Implementations send the request as Core built it and report Jev's typed answers — they never
/// author text, never retry on their own and never time out on their own: the Paste Attempt owns the 5 s clock and
/// the rate-limit retry.
public protocol DecisionService: Sendable {
    /// Starts one request and calls `reply` exactly once on the main actor. Replies that arrive after the Paste
    /// Attempt ended are ignored.
    func evaluate(_ request: NarrowingRequest, reply: @escaping @MainActor @Sendable (NarrowingReply) -> Void)
}
