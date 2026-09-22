/// Identifies the focused editable Target and its Target Context, and re-verifies the Bound Target
/// immediately before insertion.
///
/// The real adapter lives in `MacInterop` (Accessibility); tests supply an in-memory fake.
public protocol TargetResolver: Sendable {}
