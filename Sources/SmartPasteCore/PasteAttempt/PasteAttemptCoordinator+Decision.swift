/// Asking Jev and turning its reply into the next phase.
extension PasteAttemptCoordinator {
    /// Below this probability that the source contains a value for the Target, the outcome is No Suitable Match.
    static let containsValueThreshold = 0.5
    /// At or above this probability that the Target is a Free-text Target, the whole Active Item is pasted.
    static let freeTextThreshold = 0.8

    func requestDecision() {
        guard let attempt, let consultation = attempt.jevConsultation else { return }
        phase = .deciding
        let number = attempt.number
        let request = DecisionRequest(
            sourceDocument: attempt.item.text, targetContext: consultation.contextToSend.context,
            candidates: consultation.candidates
        )
        ports.decisionService.requestDecision(request) { [weak self] reply in
            guard let self, self.attempt?.number == number, phase == .deciding else { return }
            record(reply)
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
        guard decision.freeTextProbability < Self.freeTextThreshold else {
            return pasteWholeItem(intoFreeTextTargetWith: decision.freeTextProbability)
        }
        guard let attempt, let candidates = attempt.jevConsultation?.candidates else { return }
        guard case .candidate(let chosen) = decision.choice,
            decision.containsValueProbability >= Self.containsValueThreshold
        else { return finish(.noSuitableMatch) }
        guard attempt.accepts(chosen, offeredAmong: candidates) else { return finish(.failed(.invalidResult)) }
        let alternatives = rules.candidateExtraction.sameTypeAlternatives(to: chosen, among: candidates)
        if alternatives.count >= 2 {
            offerChoice(among: alternatives)
        } else {
            deliver(chosen.text)
        }
    }

    /// Records Jev's free-text judgement below the threshold on the path, whatever the decision leads to.
    private func record(_ reply: DecisionReply) {
        guard case .decided(let decision) = reply else { return }
        attempt?.path = .jev(freeTextProbability: decision.freeTextProbability)
    }

    /// A Free-text Target takes the whole pinned Active Item as a Direct Paste: no Candidates, no chooser, no
    /// Paste Result validation — the text is derived locally from the pinned item, Jev supplied only a probability.
    private func pasteWholeItem(intoFreeTextTargetWith probability: Double) {
        guard let item = attempt?.item else { return }
        attempt?.path = .freeTextTarget(probability: probability)
        deliver(DirectPasteRule.withoutOuterLineBreaks(item.text))
    }

    /// Opens the Candidate Chooser; the attempt waits for the user, off the clock.
    private func offerChoice(among alternatives: [Candidate]) {
        guard let attempt else { return }
        stopClocks()
        phase = .choosing
        let number = attempt.number
        ports.chooser.presentChoice(among: alternatives, for: attempt.target) { [weak self] choice in
            guard let self, self.attempt?.number == number, phase == .choosing else { return }
            guard let choice else { return finish(.cancelled) }
            guard attempt.accepts(choice, offeredAmong: alternatives) else { return finish(.failed(.invalidResult)) }
            deliver(choice.text)
        }
    }

    private func waitToRetry(after delay: Duration) {
        guard let deadline = attempt?.jevConsultation?.deadline, ports.clock.now + delay < deadline else {
            return finish(.failed(.timedOut))
        }
        phase = .waitingToRetry
        ports.presenter.showRetrying()
        schedule(after: delay) { coordinator in
            coordinator.requestDecision()
        }
    }
}
