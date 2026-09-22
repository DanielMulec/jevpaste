import Carbon.HIToolbox
import CoreGraphics
import SmartPasteCore

/// The `Inserter` adapter: posts one synthetic ⌘V to the frontmost app, which then pastes the clipboard that the
/// Paste Attempt has just swapped in. It posts at once: the Paste Attempt starts when V of ⌘⇧V goes up; ⌘ and ⇧
/// may still be held, which the re-probe showed to be harmless (see `GlobalHotkey`).
///
/// Insert only: this is the one keystroke jevpaste ever synthesizes. Never Return (which submits chats), never
/// a key sequence typing the text, never an AX setter (which lies outside AppKit).
public struct PasteKeystrokeInserter: Inserter {
    public init() {}

    public func postPasteKeystroke() {
        for event in Self.pasteKeystroke() {
            event.post(tap: .cghidEventTap)
        }
    }

    /// ⌘V key-down then key-up from a private event source, so no other held key is merged into it.
    /// Requires the Accessibility grant to take effect when posted.
    static func pasteKeystroke() -> [CGEvent] {
        let source = CGEventSource(stateID: .privateState)
        let virtualKey = CGKeyCode(kVK_ANSI_V)
        return [true, false].compactMap { isKeyDown in
            let event = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: isKeyDown)
            event?.flags = .maskCommand
            return event
        }
    }
}
