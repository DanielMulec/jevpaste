import AppKit
import Carbon.HIToolbox

/// Three independent global-shortcut mechanisms for Cmd+Shift+V, each logged separately so we
/// can see which ones fire, and which permission each one needs.
private func carbonHotKeyHandler(_ next: EventHandlerCallRef?,
                                 _ event: EventRef?,
                                 _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    HotkeyProbe.shared.fired(mechanism: "carbon")
    return noErr
}

private func eventTapCallback(_ proxy: CGEventTapProxy,
                              _ type: CGEventType,
                              _ event: CGEvent,
                              _ refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Log.line("eventTap DISABLED by system (\(type.rawValue)) — re-enabling")
        HotkeyProbe.shared.reenableTap()
        return Unmanaged.passUnretained(event)
    }
    if type == .keyDown {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if code == Int64(kVK_ANSI_V),
           flags.contains(.maskCommand), flags.contains(.maskShift) {
            HotkeyProbe.shared.fired(mechanism: "cgEventTap")
        }
    }
    return Unmanaged.passUnretained(event)
}

final class HotkeyProbe {
    static let shared = HotkeyProbe()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var globalMonitor: Any?

    /// Set by the `arm` command; the armed battery runs on the first mechanism that fires.
    var armedAction: (() -> Void)?
    private var lastFireAt = Date.distantPast

    func fired(mechanism: String) {
        let secureInput = IsSecureEventInputEnabled()
        let front = NSWorkspace.shared.frontmostApplication
        Log.line("HOTKEY fired via=\(mechanism) secureEventInput=\(secureInput) "
                 + "frontmost=\(front?.bundleIdentifier ?? "nil")")
        // Only one battery run per press even if several mechanisms observe the same keystroke.
        guard Date().timeIntervalSince(lastFireAt) > 0.4 else {
            Log.line("  (duplicate observation of the same press, not re-running the armed action)")
            return
        }
        lastFireAt = Date()
        guard let action = armedAction else {
            Log.line("  no action armed — use `arm <name>`")
            return
        }
        action()
    }

    // MARK: - Carbon RegisterEventHotKey (no TCC permission documented)

    func enableCarbon() -> String {
        guard hotKeyRef == nil else { return "already enabled" }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(),
                                                carbonHotKeyHandler, 1, &spec, nil, &handlerRef)
        let hotKeyID = EventHotKeyID(signature: OSType(0x4A56_5031), id: 1) // 'JVP1'
        let registerStatus = RegisterEventHotKey(UInt32(kVK_ANSI_V),
                                                 UInt32(cmdKey | shiftKey),
                                                 hotKeyID,
                                                 GetApplicationEventTarget(),
                                                 0,
                                                 &hotKeyRef)
        return "InstallEventHandler=\(installStatus) RegisterEventHotKey=\(registerStatus) "
             + "ref=\(hotKeyRef == nil ? "nil" : "ok")"
    }

    func disableCarbon() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
        if let handler = handlerRef { RemoveEventHandler(handler) }
        handlerRef = nil
    }

    // MARK: - CGEventTap (listen-only tap needs Input Monitoring)

    func enableEventTap() -> String {
        guard tap == nil else { return "already enabled" }
        let preflight = CGPreflightListenEventAccess()
        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .listenOnly,
                                           eventsOfInterest: CGEventMask(mask),
                                           callback: eventTapCallback,
                                           userInfo: nil) else {
            return "tapCreate=FAILED preflightListenEventAccess=\(preflight)"
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        tapSource = source
        return "tapCreate=ok preflightListenEventAccess=\(preflight) enabled=\(CGEvent.tapIsEnabled(tap: port))"
    }

    func reenableTap() {
        if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
    }

    func disableEventTap() {
        if let port = tap { CGEvent.tapEnable(tap: port, enable: false) }
        if let source = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        tapSource = nil
    }

    // MARK: - NSEvent global monitor (keyboard events need Accessibility)

    func enableGlobalMonitor() -> String {
        guard globalMonitor == nil else { return "already enabled" }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_ANSI_V),
               event.modifierFlags.contains(.command), event.modifierFlags.contains(.shift) {
                HotkeyProbe.shared.fired(mechanism: "nsEventGlobalMonitor")
            }
        }
        return globalMonitor == nil ? "addGlobalMonitor returned nil" : "installed"
    }

    func disableGlobalMonitor() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        globalMonitor = nil
    }

    var status: String {
        "carbon=\(hotKeyRef != nil) eventTap=\(tap != nil) globalMonitor=\(globalMonitor != nil) "
        + "armed=\(armedAction != nil)"
    }
}
