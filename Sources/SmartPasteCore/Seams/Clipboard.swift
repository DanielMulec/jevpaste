/// Reads and writes the system clipboard, including the temporary swap during the Restore Window.
///
/// The real adapter lives in `MacInterop`; tests supply an in-memory fake.
public protocol Clipboard: Sendable {}
