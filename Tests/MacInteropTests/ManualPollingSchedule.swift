import MacInterop

/// A `PollingSchedule` that ticks only when the test says so.
@MainActor
final class ManualPollingSchedule: PollingSchedule {
    private var ticks: [@MainActor () -> Void] = []

    func start(_ tick: @escaping @MainActor () -> Void) {
        ticks.append(tick)
    }

    func tick() {
        for tick in ticks { tick() }
    }
}
