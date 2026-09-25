/// The Wake Wait: when ⌘⇧V finds the focus unreadable — the Target app's accessibility tree is asleep or not yet
/// populated — the attempt re-reads it until it resolves or the limit passes, then continues exactly as if it had
/// been readable at ⌘⇧V. Off the 5 s clock, on every Smart Paste path; a click on the waking indicator cancels.
extension PasteAttemptCoordinator {
    /// Covers the 1–3 s the ChatGPT app took to wake in the live runs.
    static let wakeWaitLimit = Duration.seconds(3)
    /// A fresh Chrome tab's focus became readable ~45 ms after the first read (Gate A): it resolves on the first
    /// re-read, before the indicator could show; at most 60 reads over the limit.
    static let wakeWaitReadInterval = Duration.milliseconds(50)

    /// Reads the focus at ⌘⇧V: a readable focus continues at once, an unreadable one starts the Wake Wait.
    func bindFocusedTarget(_ start: AttemptStart) {
        switch ports.targetResolver.resolveFocusedTarget() {
        case .resolved(let target): proceed(start, into: target)
        case .noEditableTarget: refuse(.noEditableTarget)
        case .focusUnreadable(let applicationName): beginWakeWait(start, waitingFor: applicationName)
        }
    }

    private func beginWakeWait(_ start: AttemptStart, waitingFor applicationName: String) {
        wakeWait = WakeWait(start: start, applicationName: applicationName)
        phase = .wakeWaiting
        schedule(after: Self.indicatorDelay) { coordinator in
            coordinator.showWakingIndicator()
        }
        scheduleNextRead()
    }

    private func readFocusAgain() {
        guard phase == .wakeWaiting, let wakeWait else { return }
        switch ports.targetResolver.resolveFocusedTarget() {
        case .resolved(let target):
            endWakeWait(wakeWait, bindingTo: target)
        case .noEditableTarget:
            finish(.refused(.noEditableTarget))
        case .focusUnreadable:
            guard ports.clock.now - wakeWait.start.pressedAt < Self.wakeWaitLimit else {
                return finish(.refused(.targetNotReady(applicationName: wakeWait.applicationName)))
            }
            scheduleNextRead()
        }
    }

    /// The next read comes after the interval, or at the limit if that is sooner: the last read is at the limit.
    private func scheduleNextRead() {
        guard let pressedAt = wakeWait?.start.pressedAt else { return }
        let remaining = Self.wakeWaitLimit - (ports.clock.now - pressedAt)
        schedule(after: max(.zero, min(Self.wakeWaitReadInterval, remaining))) { coordinator in
            coordinator.readFocusAgain()
        }
    }

    /// The focus resolved: the wait's timers stop and the attempt continues from the Pre-checks, as from `idle`.
    private func endWakeWait(_ wakeWait: WakeWait, bindingTo target: BoundTarget) {
        stopClocks()
        self.wakeWait = nil
        phase = .idle
        var start = wakeWait.start
        start.wakeWait = ports.clock.now - start.pressedAt
        proceed(start, into: target)
    }

    private func showWakingIndicator() {
        guard let wakeWait else { return }
        self.wakeWait?.start.isIndicatorShown = true
        let number = wakeWait.start.number
        ports.presenter.showWaking(applicationName: wakeWait.applicationName) { [weak self] in
            guard let self, phase == .wakeWaiting, self.wakeWait?.start.number == number else { return }
            finish(.cancelled)
        }
    }
}

/// What a Paste Attempt carries from ⌘⇧V to its Bound Target.
struct AttemptStart {
    /// Becomes the `RunningAttempt`'s number, so stale timers and callbacks of the wait are ignored as well.
    let number: Int
    let item: ClipboardItem
    let pressedAt: ContinuousClock.Instant
    /// How long the Wake Wait lasted; `nil` when the focus was readable at ⌘⇧V.
    var wakeWait: Duration?
    /// Whether the waking indicator is up, so the processing indicator replaces it at once rather than after 150 ms.
    var isIndicatorShown = false
}

/// A Paste Attempt waiting for a readable focus.
struct WakeWait {
    var start: AttemptStart
    /// The frontmost app when the focus first read unreadable; named by the indicator and the refusal.
    let applicationName: String
}
