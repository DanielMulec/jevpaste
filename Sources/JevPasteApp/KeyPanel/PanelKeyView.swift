import AppKit

/// A key that a key-capable jevpaste panel reacts to; every other key is ignored.
enum PanelKey: Equatable {
    case moveUp
    case moveDown
    /// Return or keypad Enter.
    case confirm
    case escape
}

/// The first responder of a key-capable jevpaste panel (the Candidate Chooser, the indicator while it offers):
/// turns ↑, ↓, Return, Enter and Esc into `PanelKey`s and swallows every other key without the system beep.
final class PanelKeyView: NSView {
    private enum KeyCode {
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
    }

    var onKey: (@MainActor (PanelKey) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case KeyCode.upArrow: onKey?(.moveUp)
        case KeyCode.downArrow: onKey?(.moveDown)
        case KeyCode.returnKey, KeyCode.keypadEnter: onKey?(.confirm)
        case KeyCode.escape: onKey?(.escape)
        default: break
        }
    }
}
