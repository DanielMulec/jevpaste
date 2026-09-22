import Carbon.HIToolbox
import SmartPasteCore

/// The `Hotkey` adapter: registers ⌘⇧V system-wide with Carbon `RegisterEventHotKey`.
///
/// Chosen by the macOS probe because it needs no permission at all and still fires under secure event input. It
/// swallows the shortcut in every app, as intended: ordinary ⌘V stays untouched. Unregisters when released.
@MainActor
public final class GlobalHotkey: Hotkey {
    /// 'JVP1' — identifies our registration in the Carbon hot-key event.
    private static let hotKeyIdentifier = EventHotKeyID(signature: OSType(0x4A56_5031), id: 1)

    private var onPress: (@MainActor () -> Void)?
    nonisolated(unsafe) private var hotKeyReference: EventHotKeyRef?
    nonisolated(unsafe) private var eventHandlerReference: EventHandlerRef?

    public init() {}

    deinit {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
    }

    public func startListening(onPress: @escaping @MainActor () -> Void) {
        self.onPress = onPress
        guard eventHandlerReference == nil else { return }
        var pressedEvent = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, hotkey in GlobalHotkey.handlePress(hotkey) },
            1,
            &pressedEvent,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerReference
        )
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            Self.hotKeyIdentifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )
    }

    /// Carbon delivers application-target events on the main thread, so the hop to the main actor is an assertion.
    nonisolated private static func handlePress(_ hotkey: UnsafeMutableRawPointer?) -> OSStatus {
        guard let hotkey else { return OSStatus(eventNotHandledErr) }
        let hotkeyAddress = UInt(bitPattern: hotkey)
        MainActor.assumeIsolated {
            guard let pointer = UnsafeMutableRawPointer(bitPattern: hotkeyAddress) else { return }
            Unmanaged<GlobalHotkey>.fromOpaque(pointer).takeUnretainedValue().onPress?()
        }
        return noErr
    }
}
