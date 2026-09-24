import SmartPasteCore
import Testing

@testable import JevPasteApp

/// Acceptance-suite scaffolding: with `--accept-signal-trigger`, a signal fires the same press as ⌘⇧V; without the
/// flag, the app listens to ⌘⇧V only.
@MainActor
struct AcceptanceTriggerTests {
    private let hotkey = ListeningHotkeyDouble()
    private let trigger = PressTriggerDouble()

    @Test func theFlagIsOffByDefault() {
        #expect(!LaunchOptions(arguments: ["/Applications/JevPaste.app/Contents/MacOS/JevPaste"]).acceptsSignalTrigger)
    }

    @Test func theFlagTurnsTheSignalTriggerOn() {
        let options = LaunchOptions(arguments: ["JevPaste", "--accept-signal-trigger"])
        #expect(options.acceptsSignalTrigger)
    }

    @Test func withoutTheFlagNoTriggerIsStarted() {
        var presses = 0
        AcceptanceTrigger.hotkey(wrapping: hotkey, options: LaunchOptions(arguments: []), trigger: trigger)
            .startListening { presses += 1 }
        trigger.fire()
        hotkey.press()
        #expect(trigger.startCount == 0)
        #expect(presses == 1)
    }

    @Test func withTheFlagTheTriggerAndTheHotkeyReachTheSamePressHandler() {
        var presses = 0
        let options = LaunchOptions(arguments: ["JevPaste", "--accept-signal-trigger"])
        AcceptanceTrigger.hotkey(wrapping: hotkey, options: options, trigger: trigger)
            .startListening { presses += 1 }
        trigger.fire()
        hotkey.press()
        trigger.fire()
        #expect(trigger.startCount == 1)
        #expect(presses == 3)
    }
}

/// Stands in for the signal source: keeps the handler, so a test can "send the signal".
@MainActor
final class PressTriggerDouble: PressTrigger {
    private(set) var startCount = 0
    private var onTrigger: @MainActor () -> Void = {}

    func start(onTrigger: @escaping @MainActor () -> Void) {
        startCount += 1
        self.onTrigger = onTrigger
    }

    func fire() {
        onTrigger()
    }
}
