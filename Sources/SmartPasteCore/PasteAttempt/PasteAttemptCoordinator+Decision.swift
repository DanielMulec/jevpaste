/// Asking Jev and turning its reply into the next phase.
extension PasteAttemptCoordinator {
    /// Below this probability that the source contains a value for the Target, the outcome is No Suitable Match.
    static let containsValueThreshold = 0.5

    func requestDecision() {
        guard let attempt else { return }
        phase = .deciding
        let number = attempt.number
        let request = DecisionRequest(
            sourceDocument: attempt.item.text, targetContext: attempt.target.context, candidates: attempt.candidates
        )
        ports.decisionService.requestDecision(request) { [weak self] reply in
            guard let self, self.attempt?.number == number, phase == .deciding else { return }
            receive(reply)
        }
    }

    private func receive(_ reply: DecisionReply) {
        switch reply {
        case .rateLimited(let retryAfter):
            waitToRetry(after: retryAfter)
        case .decided(let decision):
            decided(decision)
        case .failed:
            finish(.failed(.decisionUnavailable))
        }
    }

    private func decided(_ decision: Decision) {
        guard let attempt else { return }
        guard case .candidate(let chosen) = decision.choice,
            decision.containsValueProbability >= Self.containsValueThreshold
        else { return finish(.noSuitableMatch) }
        let alternatives = rules.candidateExtraction.sameTypeAlternatives(to: chosen, among: attempt.candidates)
        if alternatives.count >= 2 {
            offerChoice(among: alternatives)
        } else {
            deliver(chosen)
        }
    }

    /// Opens the Candidate Chooser; the attempt waits for the user, off the clock.
    private func offerChoice(among alternatives: [Candidate]) {
        guard let attempt else { return }
        stopClocks()
        phase = .choosing
        let number = attempt.number
        ports.chooser.presentChoice(among: alternatives, for: attempt.target) { [weak self] choice in
            guard let self, self.attempt?.number == number, phase == .choosing else { return }
            if let choice {
                deliver(choice)
            } else {
                finish(.cancelled)
            }
        }
    }

    private func waitToRetry(after delay: Duration) {
        guard let attempt, ports.clock.now + delay < attempt.deadline else { return finish(.failed(.timedOut)) }
        phase = .waitingToRetry
        ports.presenter.showRetrying()
        schedule(after: delay) { coordinator in
            coordinator.requestDecision()
        }
    }
}
