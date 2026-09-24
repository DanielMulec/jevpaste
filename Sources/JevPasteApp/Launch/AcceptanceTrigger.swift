import Darwin
import Dispatch
import SmartPasteCore
import os

/// What the app was launched with. Open at Login and Finder launches pass no arguments, so every option is off.
struct LaunchOptions {
    /// `--accept-signal-trigger`: `SIGUSR1` presses ⌘⇧V (acceptance-suite scaffolding, see `AcceptanceTrigger`).
    let acceptsSignalTrigger: Bool

    init(arguments: [String]) {
        acceptsSignalTrigger = arguments.contains("--accept-signal-trigger")
    }
}

/// A source of ⌘⇧V presses other than the keyboard.
@MainActor
protocol PressTrigger {
    func start(onTrigger: @escaping @MainActor () -> Void)
}

/// Test scaffolding for the real-app acceptance suite: worker shells have no Accessibility grant, so they cannot
/// post ⌘⇧V. With `--accept-signal-trigger`, `kill -USR1 <pid>` reaches the very handler ⌘⇧V reaches — grant
/// check, pre-checks, Direct Paste, Jev, chooser, delivery and restore stay production code. Off by default.
enum AcceptanceTrigger {
    @MainActor
    static func hotkey(
        wrapping hotkey: any Hotkey, options: LaunchOptions, trigger: @autoclosure () -> any PressTrigger
    ) -> any Hotkey {
        guard options.acceptsSignalTrigger else { return hotkey }
        return TriggeredHotkey(wrapping: hotkey, trigger: trigger())
    }
}

/// ⌘⇧V plus a second press source, both delivered to the same handler.
@MainActor
private final class TriggeredHotkey: Hotkey {
    private let hotkey: any Hotkey
    private let trigger: any PressTrigger

    init(wrapping hotkey: any Hotkey, trigger: any PressTrigger) {
        self.hotkey = hotkey
        self.trigger = trigger
    }

    func startListening(onPress: @escaping @MainActor () -> Void) {
        hotkey.startListening(onPress: onPress)
        trigger.start(onTrigger: onPress)
    }
}

/// `SIGUSR1` on the main queue. Logs each trigger: the press timestamp the acceptance suite measures from.
@MainActor
final class SignalPressTrigger: PressTrigger {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")
    private var source: (any DispatchSourceSignal)?

    func start(onTrigger: @escaping @MainActor () -> Void) {
        guard source == nil else { return }
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                Self.log.notice("acceptance trigger (SIGUSR1)")
                onTrigger()
            }
        }
        source.resume()
        self.source = source
        Self.log.notice("acceptance signal trigger on")
    }
}
