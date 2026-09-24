# Paste Attempt state machine — port shapes and transitions

Slice: [Implement the Paste Attempt state machine over the seams](https://github.com/DanielMulec/jevpaste/issues/18).
Spec: [Choose paste lifecycle, cancellation and clipboard preservation](https://github.com/DanielMulec/jevpaste/issues/8).

## Shape
- `PasteAttemptCoordinator` (`@MainActor final class`, Core): owns the phase, drives every port. No `async` in
  Core: ports that take time answer through a `@MainActor` reply closure, so tests are synchronous and
  deterministic (fake clock `advance(by:)`, fake Jev `reply(...)`), no `Task.sleep`/`Task.yield`.
- `CopyCapture` (`@MainActor final class`, Core): holds the Active Item, records foreign copies in
  `HistoryRepository`, ignores change counts the coordinator marked as own writes. The coordinator pins
  `capture.activeItem` at ⌘⇧V and calls `capture.markOwnWrite(_:)` after each pasteboard write.
- Stale replies (after timeout/Esc) are dropped by an attempt number.

## Values (Core, `Sendable`, `Equatable`)
`ClipboardItem { text }` · `Candidate { text }` · `ClipboardSnapshot { items: [[String: Data]] }` (opaque,
byte-for-byte) · `ClipboardChange { changeCount: Int, item: ClipboardItem? }` ·
`TargetIdentity { processIdentifier: Int32, elementToken: UInt64 }` (token minted by the adapter) ·
`TargetContext { fieldLabel?, placeholder?, sectionHeading?, siblingFieldLabels, surroundingText }` ·
`BoundTarget { identity, context, isSecureField }` · `DecisionRequest { sourceDocument, targetContext,
candidates }` · `Decision { choice: .candidate(Candidate) | .noneOfThese, containsValueProbability: Double }`
· `DecisionReply = .decided(Decision) | .rateLimited(retryAfter: Duration) | .failed` ·
`PreCheckRefusal = .noEditableTarget | .secureField | .suspectedSecret | .noActiveItem` ·
`PasteAttemptFailure = .timedOut | .decisionUnavailable | .invalidResult | .targetChanged` ·
`PasteAttemptOutcome = .inserted | .insertedWithoutRestore | .noSuitableMatch | .refused(PreCheckRefusal)
| .cancelled | .failed(PasteAttemptFailure)` · `SmartPastePath = .jev | .directPaste` (diagnostics only).

## Ports
```swift
@MainActor protocol Hotkey { func startListening(onPress: @escaping @MainActor () -> Void) }
@MainActor protocol Clipboard {
    var changeCount: Int { get }
    func snapshot() -> ClipboardSnapshot
    func write(_ text: String) -> Int                    // returns the new change count
    func restore(_ snapshot: ClipboardSnapshot) -> Int   // returns the new change count
    func startObservingChanges(_ onChange: @escaping @MainActor (ClipboardChange) -> Void)
}
@MainActor protocol TargetResolver {
    func resolveFocusedTarget() -> BoundTarget?          // nil = no editable element focused
    func isStillFocused(_ target: TargetIdentity) -> Bool // same pid + same focused element
}
@MainActor protocol Inserter { func postPasteKeystroke() }   // synthetic ⌘V only; never Return
protocol DecisionService: Sendable {
    func requestDecision(_ request: DecisionRequest, reply: @escaping @MainActor @Sendable (DecisionReply) -> Void)
}
protocol HistoryRepository: Sendable { func record(_ item: ClipboardItem) }
@MainActor protocol PasteAttemptClock {
    var now: ContinuousClock.Instant { get }
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any ScheduledAction
}
@MainActor protocol ScheduledAction { func cancel() }
@MainActor protocol PasteOutcomePresenter {
    func showProcessing(onCancel: @escaping @MainActor () -> Void)   // Esc on our indicator
    func showRetrying()                                              // 429 back-off in progress
    func showOutcome(_ outcome: PasteAttemptOutcome, note: PasteAttemptNote?,   // ✓/reason + note; hides processing
                     path: SmartPastePath?)                                    // .jev / .directPaste, log only
}
@MainActor protocol CandidateChooser {   // adapter returns focus to the Bound Target's app before replying
    func presentChoice(among candidates: [Candidate], for target: BoundTarget,
                       reply: @escaping @MainActor (Candidate?) -> Void)   // nil = Esc / click-away
}
// Rule seams, stubbed in tests; real rules arrive in the Candidate derivation and Pre-check slices.
protocol CandidateExtraction: Sendable {
    func candidates(in item: ClipboardItem) -> [Candidate]
    func sameTypeAlternatives(to chosen: Candidate, among candidates: [Candidate]) -> [Candidate]  // ≥2 → chooser
}
protocol PreCheck: Sendable {   // adapter: LocalPreChecks (Core), see pre-checks.md
    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal?
    func screenedContext(of target: BoundTarget) -> ScreenedTargetContext  // pinned at ⌘⇧V, sent in every request
}
```

## Phases and transitions (`idle` → … → outcome shown → `idle`)
| phase | event | action → next phase |
|---|---|---|
| idle | ⌘⇧V, no Active Item / no target / `PreCheck` refusal | `showOutcome(.refused(r))` → idle (no Jev, no write) |
| idle | ⌘⇧V, checks pass, single-line item (`DirectPasteRule`) | Direct Paste: pin item+target, no Jev, no clocks, no indicator → delivering ([direct-paste.md](direct-paste.md)) |
| idle | ⌘⇧V, checks pass, candidates empty | `showOutcome(.noSuitableMatch)` → idle |
| idle | ⌘⇧V, checks pass | pin item+target; start 5 s deadline + 150 ms indicator timer; `requestDecision` → deciding |
| deciding, retrying, choosing, delivering | ⌘⇧V | ignored |
| deciding | 150 ms timer | `showProcessing(onCancel:)` |
| deciding | `.rateLimited(d)`, now+d < deadline | `showRetrying`; schedule retry after d → retrying |
| deciding | `.rateLimited(d)`, now+d ≥ deadline | `.failed(.timedOut)` |
| retrying | retry timer | `requestDecision` again → deciding |
| deciding, retrying | deadline timer | `.failed(.timedOut)` |
| deciding, retrying | Esc (`onCancel`) | `.cancelled` |
| deciding | `.failed` | `.failed(.decisionUnavailable)` |
| deciding | `.noneOfThese` or probability < 0.5 | `.noSuitableMatch` |
| deciding | candidate not a verbatim UTF-8 substring of pinned item | `.failed(.invalidResult)` |
| deciding | ≥ 2 same-type alternatives | stop clocks; `presentChoice` → choosing |
| deciding | otherwise | stop clocks → delivering |
| choosing | reply `nil` | `.cancelled` |
| choosing | reply candidate | validate substring → delivering |
| delivering | step start | `isStillFocused` false → `.failed(.targetChanged)`, clipboard untouched; else `snapshot`, `write` (mark own), `postPasteKeystroke`, schedule 120 ms |
| delivering | Esc | ignored |
| delivering | 120 ms, `changeCount` == own write | `restore` (mark own) → `.inserted` |
| delivering | 120 ms, `changeCount` changed | skip restore → `.insertedWithoutRestore` (capture already made the foreign copy Active) |

Every outcome cancels all timers of the attempt, then `showOutcome` (with the attempt's path) and → idle.
Active Item is never changed by the coordinator; a copy during the attempt reaches `CopyCapture` and becomes Active there.

## Clocks
- **5 s deadline**: starts when ⌘⇧V passes the pre-checks; covers Jev calls and 429 back-off; a retry is
  scheduled only if it starts before the deadline. Stops at: chooser opens (chooser is off the clock),
  delivery starts (delivery is uninterruptible), or any outcome. Not restarted after the chooser.
- **150 ms indicator**: same start; cancelled by any earlier outcome/chooser/delivery.
- **120 ms restore delay**: fixed, starts right after `postPasteKeystroke`.

## Changes to existing code
- `PasteAttemptState` (scaffold stub) and its tests are replaced by the internal phase enum.
- Placeholder adapters in `MacInterop`/`JevGateway`/`HistoryStore` get empty method bodies to compile
  (the conformance tests stay). Nothing in `JevPasteApp`.

## Decisions confirmed at GATE A
1. Reply closures instead of `async` for `DecisionService`/`CandidateChooser` (determinism, no async Core).
4. New refusal `.noActiveItem` (nothing copied yet); empty candidate list → No Suitable Match without Jev.

## Deviations from ADR 0001 table
2. 429 retry policy and the 5 s clock live in Core, not in `JevGateway` (ADR table says adapter); the adapter
   maps HTTP 429 + `retry-after` to `.rateLimited`. Retries repeat while they fit in the window.
3. The pasteboard swap + 120 ms restore sequence lives in Core over `Clipboard` + `Inserter`; `Inserter`
   shrinks to "post ⌘V" (ADR table puts the swap in the MacInterop inserter).
