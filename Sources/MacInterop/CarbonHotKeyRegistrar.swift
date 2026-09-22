import Carbon.HIToolbox

/// One Carbon hot-key event for the registered shortcut.
enum HotKeyEvent: Equatable {
    case pressed
    case released
}

/// Registers the system-wide ⌘⇧V shortcut and reports its press and release events.
@MainActor
protocol HotKeyRegistrar {
    func registerCommandShiftV(_ onEvent: @escaping @MainActor (HotKeyEvent) -> Void)
}

/// Carbon `RegisterEventHotKey`: chosen by the macOS probe because it needs no permission at all and still fires
/// under secure event input. It swallows ⌘⇧V in every app, as intended; ordinary ⌘V stays untouched.
/// Unregisters when released.
@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistrar {
    /// 'JVP1' — identifies our registration in the Carbon hot-key event.
    private static let hotKeyIdentifier = EventHotKeyID(signature: OSType(0x4A56_5031), id: 1)

    private var onEvent: (@MainActor (HotKeyEvent) -> Void)?
    nonisolated(unsafe) private var hotKeyReference: EventHotKeyRef?
    nonisolated(unsafe) private var eventHandlerReference: EventHandlerRef?

    deinit {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
    }

    func registerCommandShiftV(_ onEvent: @escaping @MainActor (HotKeyEvent) -> Void) {
        self.onEvent = onEvent
        var hotKeyEvents = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, registrar in CarbonHotKeyRegistrar.handle(event, for: registrar) },
            hotKeyEvents.count,
            &hotKeyEvents,
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
    nonisolated private static func handle(_ event: EventRef?, for registrar: UnsafeMutableRawPointer?) -> OSStatus {
        guard let event, let registrar else { return OSStatus(eventNotHandledErr) }
        let hotKeyEvent: HotKeyEvent = GetEventKind(event) == UInt32(kEventHotKeyReleased) ? .released : .pressed
        let registrarAddress = UInt(bitPattern: registrar)
        MainActor.assumeIsolated {
            guard let pointer = UnsafeMutableRawPointer(bitPattern: registrarAddress) else { return }
            Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(pointer).takeUnretainedValue().onEvent?(hotKeyEvent)
        }
        return noErr
    }
}
