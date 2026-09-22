/// Reads and writes the system clipboard, including the temporary swap during the Restore Window.
///
/// Change counts identify writes: the Paste Attempt remembers the counts its own writes produced, so they
/// never become Clipboard Items. The real adapter lives in `MacInterop`; tests supply an in-memory fake.
@MainActor
public protocol Clipboard {
    /// The clipboard's current change count; it grows with every write by anyone.
    var changeCount: Int { get }
    /// The complete current contents, byte for byte.
    func snapshot() -> ClipboardSnapshot
    /// Replaces the contents with plain text and returns the resulting change count.
    func write(_ text: String) -> Int
    /// Replaces the contents with `snapshot` and returns the resulting change count.
    func restore(_ snapshot: ClipboardSnapshot) -> Int
    /// Calls `onChange` on the main actor for every later change, own writes included.
    func startObservingChanges(_ onChange: @escaping @MainActor (ClipboardChange) -> Void)
}
