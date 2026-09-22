import Foundation
import SmartPasteCore

/// Drives the clipboard's change-count polling. macOS has no pasteboard change notification, so polling is
/// the supported mechanism; a tick always runs on a later main run-loop turn, never inside a call that wrote.
@MainActor
public protocol PollingSchedule {
    /// Calls `tick` on the main actor repeatedly until the process ends.
    func start(_ tick: @escaping @MainActor () -> Void)
}

/// The production `PollingSchedule`: a repeating main run-loop `Timer` in common modes, so polling continues
/// while menus or panels track events.
@MainActor
public final class TimerPollingSchedule: PollingSchedule {
    private let interval: Duration
    private var timer: Timer?

    public init(interval: Duration) {
        self.interval = interval
    }

    public func start(_ tick: @escaping @MainActor () -> Void) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval.timeInterval, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
