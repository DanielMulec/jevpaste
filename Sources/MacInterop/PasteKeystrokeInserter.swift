import Carbon.HIToolbox
import CoreGraphics
import SmartPasteCore

/// The `Inserter` adapter: posts one synthetic ⌘V to the frontmost app, which then pastes the clipboard that the
/// Paste Attempt has just swapped in.
///
/// Insert only: this is the one keystroke jevpaste ever synthesizes. Never Return (which submits chats), never
/// a key sequence typing the text, never an AX setter (which lies outside AppKit). It first waits, at most 1 s,
/// for the user to release ⌘⇧V: Chrome drops a synthetic ⌘V that arrives while those keys are still down.
public struct PasteKeystrokeInserter: Inserter {
    private static let pollInterval = Duration.milliseconds(10)
    private static let maximumPolls = 100

    private let keyboard: any ShortcutKeyboard
    private let post: @MainActor ([CGEvent]) -> Void

    public init() {
        self.init(keyboard: HardwareShortcutKeyboard()) { events in
            for event in events { event.post(tap: .cghidEventTap) }
        }
    }

    init(keyboard: any ShortcutKeyboard, post: @escaping @MainActor ([CGEvent]) -> Void) {
        self.keyboard = keyboard
        self.post = post
    }

    public func postPasteKeystroke() {
        var polls = 0
        while polls < Self.maximumPolls, keyboard.isPasteShortcutKeyHeld {
            keyboard.pause(for: Self.pollInterval)
            polls += 1
        }
        post(Self.pasteKeystroke())
    }

    /// ⌘V key-down then key-up from a private event source, so held hardware keys are not merged into it.
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
