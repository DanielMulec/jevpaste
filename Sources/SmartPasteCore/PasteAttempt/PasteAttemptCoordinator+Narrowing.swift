/// Narrowing inside a Paste Attempt: sending each step's request, turning Jev's replies into the next step, and the
/// outcomes Narrowing ends in. The steps and the Candidate Chooser's fill run back to back in the `deciding` phase, so
/// a click cancels between them and the 5 s clock covers them all.
extension PasteAttemptCoordinator {
    func act(on action: NarrowingAction) {
        guard let narrowing = attempt?.consultation.narrowing else { return }
        attempt?.path.narrowing = narrowing.trace
        switch action {
        case .send(let request): send(request)
        case .pasteResult(let text): deliver(text)
        case .nothingFits: offerDirectPaste()
        case .askUser(let candidates): offerChoice(among: candidates)
        case .invalidPick: finish(.failed(.invalidResult))
        case .nothingToPaste: finish(.noSuitableMatch)
        }
    }

    /// Sends `request` — a new step's, or the same one again after a rate limit.
    private func send(_ request: NarrowingRequest) {
        guard let number = attempt?.number, let decisionService = attempt?.consultation.decisionService else { return }
        phase = .deciding
        attempt?.consultation.pendingRequest = request
        attempt?.path.calls += 1
        decisionService.evaluate(request) { [weak self] reply in
            guard let self, self.attempt?.number == number, phase == .deciding else { return }
            receive(reply)
        }
    }

    private func receive(_ reply: NarrowingReply) {
        switch reply {
        case .answered(let answers):
            guard let action = attempt?.consultation.narrowing.receive(answers) else { return }
            act(on: action)
        case .rateLimited(let retryAfter):
            waitToRetry(after: retryAfter)
        case .tooLarge:
            stopNarrowing(ending: .failed(.tooLongForSmartPaste), fill: .failed)
        case .failed:
            stopNarrowing(ending: .failed(.decisionUnavailable), fill: .failed)
        }
    }

    /// The clock ran out or the Gateway failed: in the Candidate Chooser's fill with rows found, the chooser opens with
    /// them; otherwise the attempt ends with `outcome`.
    func stopNarrowing(ending outcome: PasteAttemptOutcome, fill end: ChooserFillEnd) {
        guard var narrowing = attempt?.consultation.narrowing else { return finish(outcome) }
        let rows = narrowing.stopFilling(because: end)
        attempt?.consultation.narrowing = narrowing
        attempt?.path.narrowing = narrowing.trace
        if rows.isEmpty { finish(outcome) } else { offerChoice(among: rows) }
    }

    /// Opens the Candidate Chooser with the rows Jev filled it with; the attempt waits for the user, off the clock. The
    /// pick is checked like Jev's.
    private func offerChoice(among alternatives: [Candidate]) {
        guard let attempt else { return }
        stopClocks()
        phase = .choosing
        let number = attempt.number
        ports.chooser.presentChoice(among: alternatives, for: attempt.target) { [weak self] choice in
            guard let self, self.attempt?.number == number, phase == .choosing else { return }
            guard let choice else { return finish(.cancelled) }
            guard attempt.item.acceptsPasteResult(choice, offeredAmong: alternatives) else {
                return finish(.failed(.invalidResult))
            }
            deliver(choice.text)
        }
    }

    private func waitToRetry(after delay: Duration) {
        guard let deadline = attempt?.consultation.deadline, ports.clock.now + delay < deadline else {
            return stopNarrowing(ending: .failed(.timedOut), fill: .clock)
        }
        phase = .waitingToRetry
        ports.presenter.showRetrying()
        schedule(after: delay) { coordinator in
            guard let request = coordinator.attempt?.consultation.pendingRequest else { return }
            coordinator.send(request)
        }
    }
}
