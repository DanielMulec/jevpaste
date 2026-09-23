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

    @Test func aFailedRegistrationIsReportedOnceWithItsStatus() {
        registrar.registrationStatus = -9878
        var failures: [Int32] = []
        let hotkey = GlobalHotkey(registrar: registrar) { failures.append($0) }
        hotkey.startListening {}
        hotkey.startListening {}

        #expect(failures == [-9878])
    }

    @Test func aSuccessfulRegistrationReportsNoFailure() {
        var failures: [Int32] = []
        let hotkey = GlobalHotkey(registrar: registrar) { failures.append($0) }
        hotkey.startListening {}

        #expect(failures.isEmpty)
    }
}

/// Stands in for Carbon: records registrations and lets the test deliver hot-key events.
@MainActor
final class FakeHotKeyRegistrar: HotKeyRegistrar {
    private var onEvent: (@MainActor (HotKeyEvent) -> Void)?
    private(set) var registrations = 0
    /// What the next registration returns; `noErr` unless a test makes it fail.
    var registrationStatus: Int32 = 0

    func registerCommandShiftV(_ onEvent: @escaping @MainActor (HotKeyEvent) -> Void) -> Int32 {
        registrations += 1
        self.onEvent = onEvent
        return registrationStatus
    }

    func deliver(_ event: HotKeyEvent) {
        onEvent?(event)
    }
}
