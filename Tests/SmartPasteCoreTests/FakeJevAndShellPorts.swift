import Foundation
import SmartPasteCore

/// Records every Narrowing request as sent; a test answers the oldest unanswered one, reading its options the way
/// Jev would: by id, the excerpt texts from `excerpts` (or the full-text descriptions).
final class FakeDecisionService: DecisionService {
    private let state = MainActorState()

    @MainActor
    private final class MainActorState {
        var requests: [NarrowingRequest] = []
        var pending: [(request: NarrowingRequest, reply: @MainActor (NarrowingReply) -> Void)] = []
    }

    func evaluate(_ request: NarrowingRequest, reply: @escaping @MainActor @Sendable (NarrowingReply) -> Void) {
        MainActor.assumeIsolated {
            state.requests.append(request)
            state.pending.append((request, reply))
        }
    }

    @MainActor var requests: [NarrowingRequest] { state.requests }

    @MainActor func reply(_ reply: NarrowingReply) {
        state.pending.removeFirst().reply(reply)
    }

    /// Every question of the oldest unanswered request picks the piece whose text is `text` with `probability`.
    @MainActor func pick(_ text: String, probability: Double = 0.9) {
        answer(probability: probability) { question, request in
            question.pieceOptions(in: request).first { $0.text.utf8.elementsEqual(text.utf8) }?.id ?? "unoffered"
        }
    }

    /// Every question keeps its piece unchanged (the whole copy at step 1).
    @MainActor func keep(probability: Double = 0.95) {
        answer(probability: probability) { question, _ in question.options[0].id }
    }

    @MainActor func nothingFits(probability: Double = 0.8) {
        answer(probability: probability) { _, _ in "nothing_fits" }
    }

    /// Every question asks the user, giving the listed texts (pieces, or the unchanged piece) their weights.
    @MainActor func askUser(probability: Double = 0.6, weighting weights: [(text: String, probability: Double)]) {
        answer(probability: probability, others: weights) { _, _ in "ask_user" }
    }

    /// Jev fills the Candidate Chooser after asking the user: picks each row in turn, then finds nothing more fits.
    @MainActor func fillChooser(with rows: [String]) {
        for row in rows { pick(row) }
        nothingFits()
    }

    /// Picks `text`, then keeps it at the next step: a two-step Narrowing to `text`.
    @MainActor func narrow(to text: String) {
        pick(text)
        keep()
    }

    @MainActor private func answer(
        probability: Double, others: [(text: String, probability: Double)] = [],
        choosing option: (ChoiceQuestion, NarrowingRequest) -> String
    ) {
        guard let request = state.pending.first?.request else { return }
        var answers: [String: ChoiceAnswer] = [:]
        for question in request.questions {
            let choice = option(question, request)
            let weighted = others.compactMap { weight in
                question.optionID(of: weight.text, in: request).map { ($0, weight.probability) }
            }
            let probabilities = question.options.map { option in
                let weight = weighted.first { $0.0 == option.id }?.1 ?? 0
                return OptionProbability(optionID: option.id, probability: option.id == choice ? probability : weight)
            }
            answers[question.id] = ChoiceAnswer(choice: choice, probabilities: probabilities)
        }
        reply(.answered(answers))
    }
}

extension ChoiceQuestion {
    /// The piece options with their texts: every option after the unchanged piece but `nothing_fits` and `ask_user`
    /// (a fill choice has no `ask_user`).
    func pieceOptions(in request: NarrowingRequest) -> [(id: String, text: String)] {
        options.dropFirst().filter { $0.id != "nothing_fits" && $0.id != "ask_user" }.compactMap { option in
            switch option.description {
            case .excerpt: request.excerpts.first { $0.id == option.id }.map { (option.id, $0.text) }
            case .text(let text): (option.id, text)
            case .keptPiece: nil
            }
        }
    }

    /// The option standing for `text`: a piece, or the unchanged current piece.
    func optionID(of text: String, in request: NarrowingRequest) -> String? {
        if case .onPiece(let currentPiece, _) = instructions, currentPiece.utf8.elementsEqual(text.utf8) {
            return options.first?.id
        }
        if request.sourceDocument.utf8.elementsEqual(text.utf8) { return options.first?.id }
        return pieceOptions(in: request).first { $0.text.utf8.elementsEqual(text.utf8) }?.id
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
    /// What the indicator shows, as far as a click is concerned — mirrors `IndicatorPresenter`: a click cancels only
    /// while the waking, processing or retrying indicator shows with a cancel callback.
    enum IndicatorState {
        case hidden, waking, processing, retrying, delivering, outcome, offering, hiddenWhileChoosing
    }

    private let clock: ManualClock
    private var onCancel: (@MainActor () -> Void)?
    private(set) var indicator = IndicatorState.hidden
    /// The newest cancel callback, kept after it was cleared — only for adversarial tests that call a stale one on
    /// purpose, as a misbehaving adapter would.
    private(set) var newestCancelCallback: (@MainActor () -> Void)?
    private(set) var processingShownAt: Duration?
    private(set) var wakingShownAt: Duration?
    /// The app named by each waking indicator shown, oldest first.
    private(set) var wakingApplicationNames: [String] = []
    private(set) var retryingShownCount = 0
    private(set) var outcomes: [PasteAttemptOutcome] = []
    /// The note shown with each outcome, in step with `outcomes`.
    private(set) var notes: [PasteAttemptNote?] = []
    /// The Smart Paste path of each outcome, in step with `outcomes`; `nil` when none was taken.
    private(set) var paths: [SmartPastePath?] = []
    /// How long each outcome's attempt waited for a readable focus, in step with `outcomes`; `nil` when it did not.
    private(set) var wakeWaits: [Duration?] = []
    private(set) var deliveringShownCount = 0
    /// Called when Core announces delivery, so a test can see what had happened by then.
    var onShowDelivering: (@MainActor () -> Void)?

    init(clock: ManualClock) {
        self.clock = clock
    }

    func showProcessing(onCancel: @escaping @MainActor () -> Void) {
        processingShownAt = clock.elapsed
        self.onCancel = onCancel
        newestCancelCallback = onCancel
        if indicator != .retrying { indicator = .processing }
    }

    func showWaking(applicationName: String, onCancel: @escaping @MainActor () -> Void) {
        wakingShownAt = clock.elapsed
        wakingApplicationNames.append(applicationName)
        self.onCancel = onCancel
        newestCancelCallback = onCancel
        indicator = .waking
    }

    func showRetrying() {
        retryingShownCount += 1
        indicator = .retrying
    }

    func showDelivering() {
        deliveringShownCount += 1
        if isCancellable {
            onCancel = nil
            indicator = .delivering
        }
        onShowDelivering?()
    }

    /// The Candidate Chooser opened in the indicator's place (the app's `hideWhileChoosing`): a click cannot cancel.
    func hideWhileChoosing() {
        onCancel = nil
        indicator = .hiddenWhileChoosing
    }

    func showOutcome(
        _ outcome: PasteAttemptOutcome, note: PasteAttemptNote?, path: SmartPastePath?, wakeWait: Duration?
    ) {
        outcomes.append(outcome)
        wakeWaits.append(wakeWait)
        notes.append(note)
        paths.append(path)
        shownOffer = nil  // withdrawn without a callback, as the seam promises
        onCancel = nil
        indicator = .outcome
    }

    /// A click on the indicator: cancels once, only while a cancellable indicator shows (Esc never reaches it).
    func clickIndicator() {
        guard isCancellable, let onCancel else { return }
        onCancel()
    }

    private var isCancellable: Bool {
        indicator == .waking || indicator == .processing || indicator == .retrying
    }

    // MARK: No Suitable Match offer — the seam's contract: at most one callback, only after focus is back in the
    // Target's app, none once a later `showOutcome` withdrew the offer.

    typealias OfferCallbacks = (accept: @MainActor () -> Void, dismiss: @MainActor () -> Void)

    /// The Bound Target of each offer shown, oldest first.
    private(set) var offeredTargets: [BoundTarget] = []
    /// The offer on screen, waiting for a key; `nil` once answered or withdrawn.
    private var shownOffer: OfferCallbacks?
    /// The answer given by a key, sent once focus is back in the Target's app.
    private var answerAwaitingFocusReturn: (@MainActor () -> Void)?
    /// The newest offer's callbacks, kept even after it was answered or withdrawn — only for adversarial tests that
    /// call a stale callback on purpose, as a misbehaving adapter would.
    private(set) var newestOfferCallbacks: OfferCallbacks?

    func showNoSuitableMatchOffer(
        for target: BoundTarget, onAccept: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        offeredTargets.append(target)
        onCancel = nil
        indicator = .offering
        shownOffer = (onAccept, onDismiss)
        newestOfferCallbacks = (onAccept, onDismiss)
    }

    /// Enter (`accepting`) or Esc / click-away on the shown offer; the answer waits for `finishFocusReturn()`.
    func pressOfferKey(accepting: Bool) {
        guard let offer = shownOffer else { return }
        shownOffer = nil
        answerAwaitingFocusReturn = accepting ? offer.accept : offer.dismiss
    }

    /// Focus is back in the Target's app: the pending answer goes out, once.
    func finishFocusReturn() {
        let answer = answerAwaitingFocusReturn
        answerAwaitingFocusReturn = nil
        answer?()
    }

    /// Enter on the offer, then focus back in the Target's app.
    func acceptOffer() {
        pressOfferKey(accepting: true)
        finishFocusReturn()
    }

    /// Esc or click-away on the offer, then focus back in the Target's app.
    func dismissOffer() {
        pressOfferKey(accepting: false)
        finishFocusReturn()
    }
}

/// Follows the `CandidateChooser` contract: shows one offer and replies once — with an offered Candidate or `nil` —
/// clearing the visible offer before it replies. `replyAsAMisbehavingAdapter` is the only way to reply with text that
/// was not offered or to reply again, for the adversarial tests that check Core's own guard.
@MainActor
final class FakeChooser: CandidateChooser {
    /// Called when the chooser opens; the harness hides the indicator, as the app's chooser does.
    var onPresent: (@MainActor () -> Void)?
    private var reply: (@MainActor (Candidate?) -> Void)?
    /// The newest reply callback, kept after it answered — only for `replyAsAMisbehavingAdapter`.
    private var newestReply: (@MainActor (Candidate?) -> Void)?
    /// The offer on screen; `nil` when no chooser is open.
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
        newestReply = reply
        onPresent?()
    }

    /// The user picks the offered row whose text is `text`, byte for byte; nothing happens if no such row is open.
    func choose(_ text: String) {
        guard let offered = offeredCandidates?.first(where: { $0.text.utf8.elementsEqual(text.utf8) }) else { return }
        answer(offered)
    }

    /// Esc or click-away while the chooser is open.
    func dismiss() {
        guard offeredCandidates != nil else { return }
        answer(nil)
    }

    /// A misbehaving adapter replies with `text`, offered or not, open or not.
    func replyAsAMisbehavingAdapter(with text: String) {
        newestReply?(Candidate(text: text))
    }

    private func answer(_ candidate: Candidate?) {
        let reply = reply
        self.reply = nil
        offeredCandidates = nil
        offeredTarget = nil
        reply?(candidate)
    }
}

/// Pre-check stub: refuses secure fields, and Active Items starting with a stand-in secret prefix; withholds
/// surrounding text that contains the prefix. With a `slowness`, screening moves the manual clock on by its duration,
/// like slow synchronous work on the main actor after the Bound Target resolved.
struct StubPreCheck: PreCheck {
    static let secretPrefix = "secret-"
    var slowness: (clock: ManualClock, duration: Duration)?

    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal? {
        if target.isSecureField { return .secureField }
        if item.text.hasPrefix(Self.secretPrefix) { return .suspectedSecret }
        return nil
    }

    func screenedContext(of target: BoundTarget) -> ScreenedTargetContext {
        if let slowness {
            MainActor.assumeIsolated { slowness.clock.advance(by: slowness.duration) }
        }
        guard target.context.surroundingText.contains(Self.secretPrefix) else {
            return ScreenedTargetContext(context: target.context, note: nil)
        }
        let withheld = TargetContext(fieldLabel: target.context.fieldLabel)
        return ScreenedTargetContext(context: withheld, note: .surroundingTextWithheld)
    }
}
