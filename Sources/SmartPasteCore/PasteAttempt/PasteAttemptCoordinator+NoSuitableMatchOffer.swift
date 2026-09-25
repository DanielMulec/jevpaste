/// After No Suitable Match, the attempt offers Enter to paste the whole Active Item as a Direct Paste. Never
/// automatic: only Enter inserts; Esc, click-away, ⌘⇧V or the offer's time limit end the attempt with nothing
/// inserted. The Pre-checks are not re-run — they passed at ⌘⇧V for the same pinned item and Target — and delivery
/// re-verifies the Bound Target as always.
extension PasteAttemptCoordinator {
    /// How long the offer waits for Enter; the 5 s clock is stopped while it shows.
    static let noSuitableMatchOfferTimeLimit = Duration.seconds(8)

    func offerDirectPaste() {
        guard let attempt else { return }
        stopClocks()
        phase = .offeringDirectPaste
        let number = attempt.number
        schedule(after: Self.noSuitableMatchOfferTimeLimit) { coordinator in
            coordinator.endOffer(.timedOut)
        }
        ports.presenter.showNoSuitableMatchOffer(
            for: attempt.target,
            onAccept: { [weak self] in
                guard let self, isOffering(inAttempt: number), let path = self.attempt?.path else { return }
                self.attempt?.path = path.endingOffer(.accepted)
                deliver(DirectPasteRule.withoutOuterLineBreaks(attempt.item.text))
            },
            onDismiss: { [weak self] in
                guard let self, isOffering(inAttempt: number) else { return }
                endOffer(.dismissed)
            }
        )
    }

    /// Ends the offer without inserting anything: the attempt's outcome is No Suitable Match.
    func endOffer(_ end: NoSuitableMatchOfferEnd) {
        guard phase == .offeringDirectPaste, let path = attempt?.path else { return }
        attempt?.path = path.endingOffer(end)
        finish(.noSuitableMatch)
    }

    private func isOffering(inAttempt number: Int) -> Bool {
        attempt?.number == number && phase == .offeringDirectPaste
    }
}
