/// Runs Paste Attempts, one at a time, from ⌘⇧V to their visible outcome.
///
/// Pins the Active Item at ⌘⇧V and the Bound Target once the focus is readable (after a Wake Wait if it is not yet),
/// then applies the Pre-checks. A single-line Active Item is then delivered as a Direct Paste; any other asks Jev
/// within the 5 s clock, opens the Candidate Chooser on same-type ambiguity and delivers the Paste Result. Delivery
/// is one uninterruptible step on both paths.
@MainActor
public final class PasteAttemptCoordinator {
    let ports: PasteAttemptPorts
    let rules: PasteAttemptRules
    let capture: CopyCapture
    var phase = PasteAttemptPhase.idle
    var attempt: RunningAttempt?
    /// The attempt while it waits for a readable focus, before it has a Bound Target; set only in `wakeWaiting`.
    var wakeWait: WakeWait?
    /// The running attempt's pending timers, from ⌘⇧V to its outcome.
    private var timers: [any ScheduledAction] = []
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
        attemptCount += 1
        bindFocusedTarget(AttemptStart(number: attemptCount, item: item, pressedAt: ports.clock.now))
    }

    /// Continues an attempt once its Bound Target resolved, at ⌘⇧V or at the end of a Wake Wait: the Pre-checks,
    /// then a Direct Paste or asking Jev.
    func proceed(_ start: AttemptStart, into target: BoundTarget) {
        if let refusal = rules.preCheck.refusal(for: start.item, in: target) {
            return refuse(refusal, afterWaiting: start.wakeWait)
        }
        if let directPasteText = DirectPasteRule.text(for: start.item) {
            return directPaste(directPasteText, of: start, into: target)
        }
        askJev(for: start, about: target)
    }

    /// Inserts the single-line Active Item whole: no Jev, no Candidates, no chooser, no indicator, no 5 s clock.
    private func directPaste(_ text: String, of start: AttemptStart, into target: BoundTarget) {
        attempt = RunningAttempt(
            number: start.number, item: start.item, target: target, jevConsultation: nil,
            wakeWait: start.wakeWait, path: .directPaste
        )
        deliver(text)
    }

    /// Starts the 5 s clock now, when the Bound Target has resolved; a Wake Wait before it is off the clock.
    private func askJev(for start: AttemptStart, about target: BoundTarget) {
        let candidates = rules.candidateExtraction.candidates(in: start.item)
        guard !candidates.isEmpty else {
            return ports.presenter.showOutcome(.noSuitableMatch, note: nil, path: nil, wakeWait: start.wakeWait)
        }
        let consultation = JevConsultation(
            contextToSend: rules.preCheck.screenedContext(of: target), candidates: candidates,
            deadline: ports.clock.now + Self.attemptTimeLimit
        )
        attempt = RunningAttempt(
            number: start.number, item: start.item, target: target, jevConsultation: consultation,
            wakeWait: start.wakeWait, path: .jev()
        )
        schedule(after: Self.attemptTimeLimit) { coordinator in
            coordinator.finish(.failed(.timedOut))
        }
        if start.isIndicatorShown {
            showProcessingIndicator()
        } else {
            schedule(after: Self.indicatorDelay) { coordinator in
                coordinator.showProcessingIndicator()
            }
        }
        requestDecision()
    }

    /// Runs `action` after `delay` if the current attempt is still running; any outcome cancels it.
    func schedule(after delay: Duration, _ action: @escaping @MainActor (PasteAttemptCoordinator) -> Void) {
        guard let number = runningAttemptNumber else { return }
        let timer = ports.clock.schedule(after: delay) { [weak self] in
            guard let self, runningAttemptNumber == number else { return }
            action(self)
        }
        timers.append(timer)
    }

    private var runningAttemptNumber: Int? {
        attempt?.number ?? wakeWait?.start.number
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
        let waited = attempt?.wakeWait ?? wakeWait.map { ports.clock.now - $0.start.pressedAt }
        attempt = nil
        wakeWait = nil
        phase = .idle
        ports.presenter.showOutcome(outcome, note: note, path: path, wakeWait: waited)
    }

    /// Cancels the 5 s clock, the indicator timer and any retry: the chooser and delivery run off the clock.
    func stopClocks() {
        for timer in timers {
            timer.cancel()
        }
        timers = []
    }

    func refuse(_ refusal: PreCheckRefusal, afterWaiting wakeWait: Duration? = nil) {
        ports.presenter.showOutcome(.refused(refusal), note: nil, path: nil, wakeWait: wakeWait)
    }
}
