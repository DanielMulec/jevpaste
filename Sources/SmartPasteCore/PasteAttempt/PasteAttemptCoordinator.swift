/// Runs Paste Attempts, one at a time, from ⌘⇧V to their visible outcome.
///
/// Pins the Active Item and the Bound Target at ⌘⇧V and applies the Pre-checks. A single-line Active Item is then
/// delivered as a Direct Paste; any other asks Jev within the 5 s clock, opens the Candidate Chooser on same-type
/// ambiguity and delivers the Paste Result. Delivery is one uninterruptible step on both paths.
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
        if phase == .offeringDirectPaste { return endOffer(.dismissed) }
        guard phase == .idle else { return }
        guard let item = capture.activeItem else { return refuse(.noActiveItem) }
        let target: BoundTarget
        switch ports.targetResolver.resolveFocusedTarget() {
        case .resolved(let resolved): target = resolved
        case .noEditableTarget: return refuse(.noEditableTarget)
        case .waking(let applicationName): return refuse(.targetWaking(applicationName: applicationName))
        }
        if let refusal = rules.preCheck.refusal(for: item, in: target) { return refuse(refusal) }
        if let directPasteText = DirectPasteRule.text(for: item) {
            return directPaste(directPasteText, of: item, into: target)
        }
        askJev(about: item, for: target)
    }

    /// Inserts the single-line Active Item whole: no Jev, no Candidates, no chooser, no indicator, no 5 s clock.
    private func directPaste(_ text: String, of item: ClipboardItem, into target: BoundTarget) {
        attempt = RunningAttempt(
            number: nextAttemptNumber(), item: item, target: target, jevConsultation: nil, path: .directPaste
        )
        deliver(text)
    }

    private func askJev(about item: ClipboardItem, for target: BoundTarget) {
        let candidates = rules.candidateExtraction.candidates(in: item)
        guard !candidates.isEmpty else { return ports.presenter.showOutcome(.noSuitableMatch, note: nil, path: nil) }
        let consultation = JevConsultation(
            contextToSend: rules.preCheck.screenedContext(of: target), candidates: candidates,
            deadline: ports.clock.now + Self.attemptTimeLimit
        )
        attempt = RunningAttempt(
            number: nextAttemptNumber(), item: item, target: target, jevConsultation: consultation, path: .jev()
        )
        schedule(after: Self.attemptTimeLimit) { coordinator in
            coordinator.finish(.failed(.timedOut))
        }
        schedule(after: Self.indicatorDelay) { coordinator in
            coordinator.showProcessingIndicator()
        }
        requestDecision()
    }

    private func nextAttemptNumber() -> Int {
        attemptCount += 1
        return attemptCount
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

    /// Ends the running attempt: cancels its timers, shows the outcome with the attempt's note and path and accepts
    /// the next ⌘⇧V.
    func finish(_ outcome: PasteAttemptOutcome) {
        stopClocks()
        let note = attempt?.jevConsultation?.contextToSend.note
        let path = attempt?.path
        attempt = nil
        phase = .idle
        ports.presenter.showOutcome(outcome, note: note, path: path)
    }

    /// Cancels the 5 s clock, the indicator timer and any retry: the chooser and delivery run off the clock.
    func stopClocks() {
        for timer in attempt?.timers ?? [] {
            timer.cancel()
        }
        attempt?.timers = []
    }

    private func refuse(_ refusal: PreCheckRefusal) {
        ports.presenter.showOutcome(.refused(refusal), note: nil, path: nil)
    }
}
