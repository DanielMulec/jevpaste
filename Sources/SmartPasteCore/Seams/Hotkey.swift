/// Delivers the global smart-paste shortcut (initially ⌘⇧V) that starts a Paste Attempt.
///
/// The real adapter lives in `MacInterop`; tests supply an in-memory fake.
@MainActor
public protocol Hotkey {
    /// Calls `onPress` on the main actor each time the shortcut is pressed.
    func startListening(onPress: @escaping @MainActor () -> Void)
}
