/// Asks Jev which Candidate of the Active Item belongs in the Bound Target.
///
/// The seam between the Paste Attempt and the remote decision. The real adapter lives in
/// `JevGateway`; tests supply an in-memory fake. Implementations choose among Candidates only —
/// they never author text.
public protocol DecisionService: Sendable {}
