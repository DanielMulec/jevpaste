import SmartPasteCore

/// The `Clipboard` adapter that will read and write the macOS general pasteboard.
///
/// Scaffold only: no pasteboard access yet.
public struct SystemClipboard: Clipboard {
    public init() {}

    public var changeCount: Int { 0 }

    public func snapshot() -> ClipboardSnapshot {
        ClipboardSnapshot(items: [])
    }

    public func write(_ text: String) -> Int {
        0
    }

    public func restore(_ snapshot: ClipboardSnapshot) -> Int {
        0
    }

    public func startObservingChanges(_ onChange: @escaping @MainActor (ClipboardChange) -> Void) {}
}
