import SmartPasteCore
import os

/// The `PasteOutcomePresenter`: one reused, non-focus-stealing indicator for the Wake Wait, processing, retrying and
/// every outcome. A click while waking or while Jev is choosing cancels the Paste Attempt; Esc never reaches it then,
/// because it is not key — and must not be: taking key focus during the Wake Wait would move focus off the element
/// whose readability the attempt is waiting for. Only the No Suitable Match offer takes key focus, for Enter or Esc.
@MainActor
final class IndicatorPresenter: PasteOutcomePresenter {
    private enum State {
        case hidden
        /// The Wake Wait; cancellable by a click, like processing.
        case waking
        case processing
        case retrying
        case delivering
        case outcome
        /// No Suitable Match with Enter offered; the indicator holds key focus.
        case offering
    }

    private enum OfferAnswer {
        case accept
        case dismiss
    }

    private static let log = Logger(subsystem: "jevpaste", category: "PasteAttempt")

    private let surface: any IndicatorSurface
    private let clock: any PasteAttemptClock
    private var state = State.hidden
    private var onCancel: (@MainActor () -> Void)?
    private var pendingHide: (any ScheduledAction)?
    private let offerSession: KeyPanelSession<OfferAnswer>

    init(surface: any IndicatorSurface, clock: any PasteAttemptClock, focusReturn: TargetAppFocusReturn) {
        self.surface = surface
        self.clock = clock
        offerSession = KeyPanelSession(focusReturn: focusReturn, log: Self.log)
        surface.forwardClicks { [weak self] in
            self?.indicatorClicked()
        }
        surface.forwardOfferEvents { [weak self] event in
            self?.offerEventArrived(event)
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

    func showWaking(applicationName: String, onCancel: @escaping @MainActor () -> Void) {
        self.onCancel = onCancel
        display(.waking(applicationName: applicationName), as: .waking)
        Self.log.notice("waking indicator shown")
    }

    func showRetrying() {
        display(.retrying(cancellable: onCancel != nil), as: .retrying)
        Self.log.notice("retrying after Jev asked us to wait")
    }

    /// Delivery can no longer be cancelled: a shown waking, processing or retrying indicator turns into "Pasting…"
    /// without the click hint. Anything else stays as it is — delivery ends with its outcome within the Restore Window.
    func showDelivering() {
        guard isCancellable else { return }
        onCancel = nil
        display(.delivering, as: .delivering)
        Self.log.notice("delivering indicator shown")
    }

    func showOutcome(
        _ outcome: PasteAttemptOutcome, note: PasteAttemptNote?, path: SmartPastePath?, wakeWait: Duration?
    ) {
        let line = Self.outcomeLogLine(outcome, note: note, path: path, wakeWait: wakeWait)
        Self.log.notice("\(line, privacy: .public)")
        show(OutcomeMessage(outcome, note: note))
    }

    /// Takes key focus for Enter or Esc; the answer goes to Core once focus is back in the Bound Target's app.
    func showNoSuitableMatchOffer(
        for target: BoundTarget, onAccept: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        let isNew = offerSession.begin(returningFocusTo: target.identity.processIdentifier) { answer in
            answer == .accept ? onAccept() : onDismiss()
        }
        guard isNew else { return onDismiss() }  // defensive: Core runs one attempt, so one offer, at a time
        onCancel = nil
        pendingHide?.cancel()
        pendingHide = nil
        state = .offering
        surface.displayTakingKeyFocus(.noSuitableMatchOffer)
        Self.log.notice("offer shown")
    }

    /// The diagnostic line for an outcome: its kind, the Narrowing path, the Wake Wait in whole milliseconds when the
    /// attempt waited, and the note — fixed names and numbers only, no payload.
    /// `outcome inserted via=narrowing steps=2 calls=2 p=0.97 questions=1,1 wakeWait=312`,
    /// `outcome refused.targetNotReady wakeWait=3000`,
    /// `outcome noSuitableMatch via=narrowing … offer=dismissed note=…`.
    static func outcomeLogLine(
        _ outcome: PasteAttemptOutcome, note: PasteAttemptNote?, path: SmartPastePath?, wakeWait: Duration? = nil
    ) -> String {
        let pathName = path.map { " " + $0.logFragment } ?? ""
        let wakeWaitValue = wakeWait.map { " wakeWait=\(Int($0 / .milliseconds(1)))" } ?? ""
        let noteName = note.map { " note=\($0)" } ?? ""
        return "outcome \(OutcomeMessage.logName(for: outcome))\(pathName)\(wakeWaitValue)\(noteName)"
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

    /// An outcome while offering withdraws the offer (Core's time limit or ⌘⇧V ended it): no answer, focus back.
    private func show(_ message: OutcomeMessage) {
        onCancel = nil
        let wasOffering = state == .offering
        display(message.content, as: .outcome)
        if wasOffering { offerSession.abandon() }
        pendingHide = clock.schedule(after: message.displayDuration) { [weak self] in
            self?.hide()
        }
    }

    /// Enter accepts, Esc or click-away dismisses; the indicator is hidden before focus goes back.
    private func offerEventArrived(_ event: IndicatorOfferEvent) {
        guard state == .offering else { return }
        state = .hidden
        switch event {
        case .accept:
            Self.log.notice("offer accepted")
            offerSession.answer(.accept) { surface.hide() }
        case .dismiss(let dismissal):
            Self.log.notice("offer dismissed (\(dismissal.rawValue, privacy: .public))")
            offerSession.answer(.dismiss) { surface.hide() }
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

    private var isCancellable: Bool {
        state == .waking || state == .processing || state == .retrying
    }

    private func indicatorClicked() {
        guard isCancellable, let onCancel else { return }
        Self.log.notice("cancel clicked")
        onCancel()
    }
}
