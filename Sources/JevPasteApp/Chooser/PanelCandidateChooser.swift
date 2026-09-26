import SmartPasteCore
import os

/// The `CandidateChooser`: offers Core's rows (Jev's chooser fill) in one reused panel in the indicator's place.
/// ↑/↓ move, Enter or a click chooses, Esc or click-away cancels. Either way it closes, hands focus back to the
/// Bound Target's app, and only then replies — exactly once, with the untouched `Candidate` or `nil`.
@MainActor
final class PanelCandidateChooser: CandidateChooser {
    private struct OpenChoice {
        let candidates: [Candidate]
        var selectedRow = 0
    }

    private static let log = Logger(subsystem: "jevpaste", category: "CandidateChooser")

    private let surface: any ChooserSurface
    private let session: KeyPanelSession<Candidate?>
    private let indicator: IndicatorPresenter
    /// The choice while the chooser is open; `nil` once it was answered, so later events are ignored.
    private var openChoice: OpenChoice?

    init(surface: any ChooserSurface, focusReturn: TargetAppFocusReturn, indicator: IndicatorPresenter) {
        self.surface = surface
        session = KeyPanelSession(focusReturn: focusReturn, log: Self.log)
        self.indicator = indicator
        surface.forwardEvents { [weak self] event in
            self?.handle(event)
        }
    }

    /// Opens the chooser. A call while a choice is still open is declined at once with `nil` and leaves the open
    /// choice untouched, so every caller gets exactly one reply; Core never does this, as it runs one attempt at a
    /// time. A reply that opens the next choice synchronously finds the chooser answered and free.
    func presentChoice(
        among candidates: [Candidate],
        for target: BoundTarget,
        reply: @escaping @MainActor (Candidate?) -> Void
    ) {
        guard session.begin(returningFocusTo: target.identity.processIdentifier, reply: reply) else {
            Self.log.error("chooser already open; declined a second choice")
            return reply(nil)
        }
        openChoice = OpenChoice(candidates: candidates)
        indicator.hideWhileChoosing()
        surface.open(ChooserContent(candidates: candidates, context: target.context), selecting: 0)
        Self.log.notice("chooser opened with \(candidates.count, privacy: .public) alternatives")
    }

    private func handle(_ event: ChooserEvent) {
        guard let choice = openChoice else { return }
        switch event {
        case .moveUp:
            select(choice.selectedRow - 1)
        case .moveDown:
            select(choice.selectedRow + 1)
        case .chooseSelected:
            choose(row: choice.selectedRow)
        case .choose(let row):
            choose(row: row)
        case .cancel(let dismissal):
            Self.log.notice("cancelled (\(dismissal.rawValue, privacy: .public))")
            answer(with: nil)
        }
    }

    private func select(_ row: Int) {
        guard let choice = openChoice else { return }
        let clamped = min(max(row, 0), choice.candidates.count - 1)
        openChoice?.selectedRow = clamped
        surface.select(clamped)
    }

    private func choose(row: Int) {
        guard let choice = openChoice, choice.candidates.indices.contains(row) else { return }
        Self.log.notice("chose index \(row, privacy: .public)")
        answer(with: choice.candidates[row])
    }

    /// The session replies once focus is back in the Bound Target's app.
    private func answer(with candidate: Candidate?) {
        openChoice = nil
        session.answer(candidate) { surface.close() }
    }
}
