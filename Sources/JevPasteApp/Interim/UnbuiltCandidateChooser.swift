import SmartPasteCore

/// Interim `CandidateChooser` for the tracer bullet: the real chooser is its own slice. It declines at once, so
/// several same-type matches end as a cancellation that says so — never a guess among them. Remove it, and
/// `IndicatorPresenter.explainNextCancellationAsChooserNotBuilt()`, with "Candidate Chooser UI".
@MainActor
final class UnbuiltCandidateChooser: CandidateChooser {
    private let presenter: IndicatorPresenter

    init(presenter: IndicatorPresenter) {
        self.presenter = presenter
    }

    func presentChoice(
        among candidates: [Candidate],
        for target: BoundTarget,
        reply: @escaping @MainActor (Candidate?) -> Void
    ) {
        presenter.explainNextCancellationAsChooserNotBuilt()
        reply(nil)
    }
}
