/// Inserts the Paste Result into the Bound Target. Insert only; never sends or executes.
///
/// The real adapter lives in `MacInterop` (pasteboard swap); tests supply an in-memory fake.
public protocol Inserter: Sendable {}
