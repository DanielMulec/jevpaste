import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Whether the user still holds a key of the ⌘⇧V shortcut. The Inserter waits for their release: while the
/// physical keys are down, Chrome ignores the synthetic ⌘V (proved by the signed probe run).
@MainActor
protocol ShortcutKeyboard {
    var isPasteShortcutKeyHeld: Bool { get }
    /// Blocks the caller between two polls.
    func pause(for duration: Duration)
}

/// The hardware key state as the HID system sees it.
struct HardwareShortcutKeyboard: ShortcutKeyboard {
    private static let shortcutKeys = [kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift, kVK_ANSI_V]

    var isPasteShortcutKeyHeld: Bool {
        Self.shortcutKeys.contains { CGEventSource.keyState(.hidSystemState, key: CGKeyCode($0)) }
    }

    func pause(for duration: Duration) {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        Thread.sleep(forTimeInterval: seconds)
    }
}
