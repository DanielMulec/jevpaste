import Testing

@testable import MacInterop

@MainActor
struct GlobalHotkeyTests {
    private let registrar = FakeHotKeyRegistrar()

    @Test func releasingTheShortcutStartsAPasteAttempt() {
        let hotkey = GlobalHotkey(registrar: registrar)
        var attempts = 0
        hotkey.startListening { attempts += 1 }

        registrar.deliver(.pressed)
        registrar.deliver(.released)

        #expect(attempts == 1)
    }

    @Test func pressingTheShortcutAloneStartsNothing() {
        let hotkey = GlobalHotkey(registrar: registrar)
        var attempts = 0
        hotkey.startListening { attempts += 1 }

        registrar.deliver(.pressed)

        #expect(attempts == 0)
    }

    @Test func listeningTwiceRegistersTheShortcutOnce() {
        let hotkey = GlobalHotkey(registrar: registrar)
        hotkey.startListening {}
        hotkey.startListening {}

        #expect(registrar.registrations == 1)
    }
}

/// Stands in for Carbon: records registrations and lets the test deliver hot-key events.
@MainActor
final class FakeHotKeyRegistrar: HotKeyRegistrar {
    private var onEvent: (@MainActor (HotKeyEvent) -> Void)?
    private(set) var registrations = 0

    func registerCommandShiftV(_ onEvent: @escaping @MainActor (HotKeyEvent) -> Void) {
        registrations += 1
        self.onEvent = onEvent
    }

    func deliver(_ event: HotKeyEvent) {
        onEvent?(event)
    }
}
