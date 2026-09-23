/// Runs Paste Attempts, one at a time, from ⌘⇧V to their visible outcome.
///
/// Pins the Active Item and the Bound Target at ⌘⇧V, applies the Pre-checks, asks Jev within the 5 s clock,
/// opens the Candidate Chooser on same-type ambiguity and delivers the Paste Result in one uninterruptible step.
@MainActor
public final class PasteAttemptCoordinator {
    let ports: PasteAttemptPorts
    let rules: PasteAttemptRules
    let capture: CopyCapture
    var phase = PasteAttemptPhase.idle
    var attempt: RunningAttempt?
    private var attemptCount = 0

    /// The processing indicator is visible by this delay after ⌘⇧V unless the attempt ended sooner.
    static let indicatorDelay = Duration.milliseconds(150)
    /// The hard clock over the whole attempt, rate-limit back-off included; the Candidate Chooser is off it.
    static let attemptTimeLimit = Duration.seconds(5)

    public init(ports: PasteAttemptPorts, rules: PasteAttemptRules, capture: CopyCapture) {
        self.ports = ports
        self.rules = rules
        self.capture = capture
        ports.hotkey.startListening { [weak self] in
            self?.hotkeyPressed()
        }
    }

    private func hotkeyPressed() {
        guard phase == .idle else { return }
        guard let item = capture.activeItem else { return refuse(.noActiveItem) }
        guard let target = ports.targetResolver.resolveFocusedTarget() else { return refuse(.noEditableTarget) }
        if let refusal = rules.preCheck.refusal(for: item, in: target) { return refuse(refusal) }
        let candidates = rules.candidateExtraction.candidates(in: item)
        guard !candidates.isEmpty else { return ports.presenter.showOutcome(.noSuitableMatch, note: nil) }
        attemptCount += 1
        attempt = RunningAttempt(
            number: attemptCount, item: item, target: target, contextToSend: rules.preCheck.screenedContext(of: target),
            candidates: candidates, deadline: ports.clock.now + Self.attemptTimeLimit
        )
        schedule(after: Self.attemptTimeLimit) { coordinator in
            coordinator.finish(.failed(.timedOut))
        }
        schedule(after: Self.indicatorDelay) { coordinator in
            coordinator.showProcessingIndicator()
        }
        requestDecision()
    }

    /// Runs `action` after `delay` if the current attempt is still running; any outcome cancels it.
    func schedule(after delay: Duration, _ action: @escaping @MainActor (PasteAttemptCoordinator) -> Void) {
        guard let number = attempt?.number else { return }
        let timer = ports.clock.schedule(after: delay) { [weak self] in
            guard let self, attempt?.number == number else { return }
            action(self)
        }
        attempt?.timers.append(timer)
    }

    private func showProcessingIndicator() {
        guard let number = attempt?.number else { return }
        ports.presenter.showProcessing { [weak self] in
            guard let self, attempt?.number == number else { return }
            escapePressed()
        }
    }

    /// Esc on our indicator cancels while waiting for Jev; once delivery started it has no effect.
    private func escapePressed() {
        guard phase == .deciding || phase == .waitingToRetry else { return }
        finish(.cancelled)
    }

    /// Ends the running attempt: cancels its timers, shows the outcome with the attempt's note and accepts the
    /// next ⌘⇧V.
    func finish(_ outcome: PasteAttemptOutcome) {
        stopClocks()
        let note = attempt?.contextToSend.note
        attempt = nil
        phase = .idle
        ports.presenter.showOutcome(outcome, note: note)
    }

    /// Cancels the 5 s clock, the indicator timer and any retry: the chooser and delivery run off the clock.
    func stopClocks() {
        for timer in attempt?.timers ?? [] {
            timer.cancel()
        }
        attempt?.timers = []
    }

    private func refuse(_ refusal: PreCheckRefusal) {
        ports.presenter.showOutcome(.refused(refusal), note: nil)
    }
}
