import Foundation

/// A captured piece of copied text that can serve as the source of a Smart Paste.
public struct ClipboardItem: Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

/// The complete clipboard contents at one instant, kept byte for byte so it can be restored exactly.
///
/// Opaque to Core: each item maps a type identifier to its bytes. Only the `Clipboard` adapter reads it.
public struct ClipboardSnapshot: Equatable, Sendable {
    public let items: [[String: Data]]

    public init(items: [[String: Data]]) {
        self.items = items
    }
}

/// One observed change of the system clipboard.
public struct ClipboardChange: Equatable, Sendable {
    /// The clipboard's change count after the change; own writes are recognised by it.
    public let changeCount: Int
    /// The copied text, or `nil` when the new contents carry no text.
    public let item: ClipboardItem?

    public init(changeCount: Int, item: ClipboardItem?) {
        self.changeCount = changeCount
        self.item = item
    }
}
