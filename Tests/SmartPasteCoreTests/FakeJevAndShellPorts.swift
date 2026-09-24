import Foundation
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

/// In-memory Clipboard History that follows the `HistoryRepository` contract (refusals, trimmed-text identity,
/// move-to-top, retention), and also logs every `record` call in `recordedItems`.
final class FakeHistoryRepository: HistoryRepository {
    private let state: MainActorState

    @MainActor
    private final class MainActorState {
        var recordedItems: [ClipboardItem] = []
        /// Newest first.
        var history: [ClipboardItem] = []
        var retentionLimit: Int

        init(retentionLimit: Int) {
            self.retentionLimit = retentionLimit
        }

        func evictBeyondRetentionLimit() {
            history = Array(history.prefix(retentionLimit))
        }
    }

    init(retentionLimit: Int = 500) {
        state = MainActor.assumeIsolated { MainActorState(retentionLimit: max(retentionLimit, 1)) }
    }

    /// The contract's identity: the text's UTF-8 bytes after trimming; `nil` for blank text.
    private static func identity(of item: ClipboardItem) -> [UInt8]? {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Array(trimmed.utf8)
    }

    func record(_ item: ClipboardItem) {
        MainActor.assumeIsolated {
            state.recordedItems.append(item)
            guard !item.isConcealed, let identity = Self.identity(of: item) else { return }
            state.history.removeAll { Self.identity(of: $0) == identity }
            state.history.insert(item, at: 0)
            state.evictBeyondRetentionLimit()
        }
    }

    func items() -> [ClipboardItem] {
        MainActor.assumeIsolated { state.history }
    }

    func delete(_ item: ClipboardItem) {
        guard let identity = Self.identity(of: item) else { return }
        MainActor.assumeIsolated { state.history.removeAll { Self.identity(of: $0) == identity } }
    }

    func clearAll() {
        MainActor.assumeIsolated { state.history.removeAll() }
    }

    func changeRetentionLimit(to limit: Int) {
        MainActor.assumeIsolated {
            state.retentionLimit = max(limit, 1)
            state.evictBeyondRetentionLimit()
        }
    }

    /// Every item passed to `record`, oldest first, including refused ones.
    @MainActor var recordedItems: [ClipboardItem] { state.recordedItems }
}

@MainActor
final class FakePresenter: PasteOutcomePresenter {
    private let clock: ManualClock
    private var onCancel: (@MainActor () -> Void)?
    private(set) var processingShownAt: Duration?
    private(set) var retryingShownCount = 0
    private(set) var outcomes: [PasteAttemptOutcome] = []
    /// The note shown with each outcome, in step with `outcomes`.
    private(set) var notes: [PasteAttemptNote?] = []
    /// The Smart Paste path of each outcome, in step with `outcomes`; `nil` when none was taken.
    private(set) var paths: [SmartPastePath?] = []
    private(set) var deliveringShownCount = 0
    /// Called when Core announces delivery, so a test can see what had happened by then.
    var onShowDelivering: (@MainActor () -> Void)?

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

    func showDelivering() {
        deliveringShownCount += 1
        onShowDelivering?()
    }

    func showOutcome(_ outcome: PasteAttemptOutcome, note: PasteAttemptNote?, path: SmartPastePath?) {
        outcomes.append(outcome)
        notes.append(note)
        paths.append(path)
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

/// Pre-check stub: refuses secure fields, and Active Items starting with a stand-in secret prefix; withholds
/// surrounding text that contains the prefix.
struct StubPreCheck: PreCheck {
    static let secretPrefix = "secret-"

    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal? {
        if target.isSecureField { return .secureField }
        if item.text.hasPrefix(Self.secretPrefix) { return .suspectedSecret }
        return nil
    }

    func screenedContext(of target: BoundTarget) -> ScreenedTargetContext {
        guard target.context.surroundingText.contains(Self.secretPrefix) else {
            return ScreenedTargetContext(context: target.context, note: nil)
        }
        let withheld = TargetContext(fieldLabel: target.context.fieldLabel)
        return ScreenedTargetContext(context: withheld, note: .surroundingTextWithheld)
    }
}
