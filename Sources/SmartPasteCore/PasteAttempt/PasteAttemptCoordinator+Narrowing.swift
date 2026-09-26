/// Narrowing inside a Paste Attempt: sending each step's request, turning Jev's replies into the next step, and the
/// outcomes Narrowing ends in. The steps run back to back in the `deciding` phase, so a click cancels between them and
/// the 5 s clock covers them all.
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
        guard let number = attempt?.number else { return }
        phase = .deciding
        attempt?.consultation.pendingRequest = request
        attempt?.path.calls += 1
        ports.decisionService.evaluate(request) { [weak self] reply in
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
            finish(.failed(.tooLongForSmartPaste))
        case .failed:
            finish(.failed(.decisionUnavailable))
        }
    }

    /// Opens the Candidate Chooser; the attempt waits for the user, off the clock. The pick is checked like Jev's; a
    /// picked whole copy is pasted with its outer line breaks stripped, like every whole-copy paste.
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
            let isWholeCopy = choice.text.utf8.elementsEqual(attempt.item.text.utf8)
            deliver(isWholeCopy ? OuterLineBreaks.stripped(from: choice.text) : choice.text)
        }
    }

    private func waitToRetry(after delay: Duration) {
        guard let deadline = attempt?.consultation.deadline, ports.clock.now + delay < deadline else {
            return finish(.failed(.timedOut))
        }
        phase = .waitingToRetry
        ports.presenter.showRetrying()
        schedule(after: delay) { coordinator in
            guard let request = coordinator.attempt?.consultation.pendingRequest else { return }
            coordinator.send(request)
        }
    }
}
