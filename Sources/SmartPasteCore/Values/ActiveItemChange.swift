/// The Active Item was replaced, and why.
public struct ActiveItemChange: Equatable, Sendable {
    public enum Cause: Equatable, Sendable {
        /// A new copy from another app (never the Paste Attempt's own writes).
        case copied
        /// An explicit selection from Clipboard History inside the app.
        case selected
        /// The same item, now concealed: its text was just excluded (a Jev Provider key stored in Settings).
        case excluded
    }

    public let item: ClipboardItem
    public let cause: Cause

    public init(item: ClipboardItem, cause: Cause) {
        self.item = item
        self.cause = cause
    }
}
