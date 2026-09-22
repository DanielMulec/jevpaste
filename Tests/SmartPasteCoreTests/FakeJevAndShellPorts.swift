import SmartPasteCore

/// Records every request; a test answers the latest one with `reply(_:)`.
final class FakeDecisionService: DecisionService {
    private let state = MainActorState()

    @MainActor
    private final class MainActorState {
        var requests: [DecisionRequest] = []
        var pendingReplies: [@MainActor (DecisionReply) -> Void] = []
    }

    func requestDecision(_ request: DecisionRequest, reply: @escaping @MainActor @Sendable (DecisionReply) -> Void) {
        MainActor.assumeIsolated {
            state.requests.append(request)
            state.pendingReplies.append(reply)
        }
    }

    @MainActor var requests: [DecisionRequest] { state.requests }

    @MainActor func reply(_ reply: DecisionReply) {
        state.pendingReplies.removeFirst()(reply)
    }

    @MainActor func choose(_ text: String, probability: Double = 0.9) {
        reply(.decided(Decision(choice: .candidate(Candidate(text: text)), containsValueProbability: probability)))
    }
}

final class FakeHistoryRepository: HistoryRepository {
    private let state = MainActorState()

    @MainActor
    private final class MainActorState {
        var items: [ClipboardItem] = []
    }

    func record(_ item: ClipboardItem) {
        MainActor.assumeIsolated { state.items.append(item) }
    }

    @MainActor var items: [ClipboardItem] { state.items }
}

@MainActor
final class FakePresenter: PasteOutcomePresenter {
    private let clock: ManualClock
    private var onCancel: (@MainActor () -> Void)?
    private(set) var processingShownAt: Duration?
    private(set) var retryingShownCount = 0
    private(set) var outcomes: [PasteAttemptOutcome] = []

    init(clock: ManualClock) {
        self.clock = clock
    }

    func showProcessing(onCancel: @escaping @MainActor () -> Void) {
        processingShownAt = clock.elapsed
        self.onCancel = onCancel
    }

    func showRetrying() {
        retryingShownCount += 1
    }

    func showOutcome(_ outcome: PasteAttemptOutcome) {
        outcomes.append(outcome)
    }

    /// Esc pressed while our processing indicator is visible.
    func pressEscape() {
        onCancel?()
    }
}

@MainActor
final class FakeChooser: CandidateChooser {
    private var reply: (@MainActor (Candidate?) -> Void)?
    private(set) var offeredCandidates: [Candidate]?
    private(set) var offeredTarget: BoundTarget?

    func presentChoice(
        among candidates: [Candidate],
        for target: BoundTarget,
        reply: @escaping @MainActor (Candidate?) -> Void
    ) {
        offeredCandidates = candidates
        offeredTarget = target
        self.reply = reply
    }

    func choose(_ text: String) {
        reply?(Candidate(text: text))
    }

    func dismiss() {
        reply?(nil)
    }
}

/// Candidate derivation stub: the fixed Candidates found in the item; every Candidate listed in `sameTypeGroup`
/// shares one type.
struct StubCandidateExtraction: CandidateExtraction {
    var fixedCandidates: [Candidate]
    var sameTypeGroup: [Candidate] = []

    func candidates(in item: ClipboardItem) -> [Candidate] {
        fixedCandidates.filter { item.text.contains($0.text) }
    }

    func sameTypeAlternatives(to chosen: Candidate, among candidates: [Candidate]) -> [Candidate] {
        sameTypeGroup.contains(chosen) ? sameTypeGroup.filter(candidates.contains) : [chosen]
    }
}

/// Pre-check stub: refuses secure fields, and Active Items starting with a stand-in secret prefix.
struct StubPreCheck: PreCheck {
    static let secretPrefix = "secret-"

    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal? {
        if target.isSecureField { return .secureField }
        if item.text.hasPrefix(Self.secretPrefix) { return .suspectedSecret }
        return nil
    }
}
