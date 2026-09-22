/// Delivers the global smart-paste shortcut (initially ⌘⇧V) that starts a Paste Attempt.
///
/// The real adapter lives in `MacInterop`; tests supply an in-memory fake.
public protocol Hotkey: Sendable {}
