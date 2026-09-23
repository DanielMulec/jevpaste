import SmartPasteCore
import os

/// The `PasteOutcomePresenter`: one reused, non-focus-stealing indicator for processing, retrying and every
/// outcome. A click while Jev is choosing cancels the Paste Attempt; Esc never reaches it, because it is never key.
@MainActor
final class IndicatorPresenter: PasteOutcomePresenter {
    private enum State {
        case hidden
        case processing
        case retrying
        case outcome
    }

    private static let log = Logger(subsystem: "jevpaste", category: "PasteAttempt")

    private let surface: any IndicatorSurface
    private let clock: any PasteAttemptClock
    private var state = State.hidden
    private var onCancel: (@MainActor () -> Void)?
    private var pendingHide: (any ScheduledAction)?

    init(surface: any IndicatorSurface, clock: any PasteAttemptClock) {
        self.surface = surface
        self.clock = clock
        surface.forwardClicks { [weak self] in
            self?.indicatorClicked()
        }
    }

    func showProcessing(onCancel: @escaping @MainActor () -> Void) {
        self.onCancel = onCancel
        // A rate limit that arrived before the 150 ms mark keeps its retrying label, now with the click hint.
        if state == .retrying {
            display(.retrying(cancellable: true), as: .retrying)
        } else {
            display(.processing(cancellable: true), as: .processing)
        }
        Self.log.notice("processing indicator shown")
    }

    func showRetrying() {
        display(.retrying(cancellable: onCancel != nil), as: .retrying)
        Self.log.notice("retrying after Jev asked us to wait")
    }

    func showDelivering() {}

    func showOutcome(_ outcome: PasteAttemptOutcome) {
        Self.log.notice("outcome \(OutcomeMessage.logName(for: outcome), privacy: .public)")
        show(OutcomeMessage(outcome))
    }

    /// The Candidate Chooser opened in the indicator's place: hides it, and a click can no longer cancel. The
    /// outcome that follows the choice is shown as usual.
    func hideWhileChoosing() {
        onCancel = nil
        pendingHide?.cancel()
        pendingHide = nil
        hide()
        Self.log.notice("processing indicator hidden while choosing")
    }

    private func show(_ message: OutcomeMessage) {
        onCancel = nil
        display(message.content, as: .outcome)
        pendingHide = clock.schedule(after: message.displayDuration) { [weak self] in
            self?.hide()
        }
    }

    private func display(_ content: IndicatorContent, as newState: State) {
        pendingHide?.cancel()
        pendingHide = nil
        state = newState
        surface.display(content)
    }

    private func hide() {
        state = .hidden
        surface.hide()
    }

    private func indicatorClicked() {
        guard state == .processing || state == .retrying, let onCancel else { return }
        Self.log.notice("cancel clicked")
        onCancel()
    }
}
