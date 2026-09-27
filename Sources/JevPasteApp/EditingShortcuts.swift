import AppKit

/// ⌘X, ⌘C, ⌘V, ⌘A and ⌘Z for jevpaste's text fields: an accessory app has no Edit menu, which is where these
/// shortcuts normally live. The History Search field and the Settings window route their key equivalents here.
@MainActor
enum EditingShortcuts {
    private static let actions: [String: Selector] = [
        "x": #selector(NSText.cut(_:)), "c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)),
        "a": #selector(NSText.selectAll(_:)), "z": Selector(("undo:")),
    ]

    /// Sends the editing action for `event` to the first responder; `false` when `event` is not one of them.
    static func perform(_ event: NSEvent, from sender: NSResponder) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
            let key = event.charactersIgnoringModifiers, let action = actions[key]
        else { return false }
        return NSApp.sendAction(action, to: nil, from: sender)
    }
}

/// The History Search field: a search field (magnifier, ✕ to clear) that takes the editing shortcuts.
final class EditingSearchField: NSSearchField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        EditingShortcuts.perform(event, from: self) || super.performKeyEquivalent(with: event)
    }
}
