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
`BoundTarget { identity, context, isSecureField }` · `NarrowingRequest { sourceDocument, targetContext, excerpts,
questions }` and `NarrowingReply = .answered([questionID: ChoiceAnswer]) | .rateLimited(retryAfter: Duration) |
.tooLarge | .failed` (one Narrowing step; [narrowing.md](narrowing.md)) ·
`PreCheckRefusal = .noEditableTarget | .targetNotReady(applicationName:) | .secureField | .suspectedSecret |
.noActiveItem` ·
`PasteAttemptFailure = .timedOut | .decisionUnavailable | .tooLongForSmartPaste | .invalidResult | .targetChanged` ·
`PasteAttemptOutcome = .inserted | .insertedWithoutRestore | .noSuitableMatch | .refused(PreCheckRefusal)
| .cancelled | .failed(PasteAttemptFailure)` · `SmartPastePath { narrowing: NarrowingTrace, calls,
noSuitableMatchOfferEnd? }` (diagnostics only; stored on the running attempt, refined with every request and step
and when the No Suitable Match offer ends) · `NoSuitableMatchOfferEnd = .accepted | .dismissed | .timedOut`.

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
    func resolveFocusedTarget() -> TargetResolution      // .resolved(BoundTarget) | .noEditableTarget
                                                         // | .focusUnreadable(applicationName:) → Wake Wait
    func isStillFocused(_ target: TargetIdentity) -> Bool // same pid + same focused element
}
@MainActor protocol Inserter { func postPasteKeystroke() }   // synthetic ⌘V only; never Return
protocol DecisionService: Sendable {   // one Narrowing step per call
    func evaluate(_ request: NarrowingRequest, reply: @escaping @MainActor @Sendable (NarrowingReply) -> Void)
}
protocol HistoryRepository: Sendable { func record(_ item: ClipboardItem) }
@MainActor protocol PasteAttemptClock {
    var now: ContinuousClock.Instant { get }
    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> any ScheduledAction
}
@MainActor protocol ScheduledAction { func cancel() }
@MainActor protocol PasteOutcomePresenter {
    func showProcessing(onCancel: @escaping @MainActor () -> Void)   // click on our indicator
    func showWaking(applicationName: String, onCancel: @escaping @MainActor () -> Void)  // Wake Wait, click cancels
    func showRetrying()                                              // 429 back-off in progress
    func showOutcome(_ outcome: PasteAttemptOutcome, note: PasteAttemptNote?,   // ✓/reason + note; hides processing
                     path: SmartPastePath?, wakeWait: Duration?)               // path, Wake Wait: log only
    func showNoSuitableMatchOffer(for target: BoundTarget,                      // Enter pastes everything; at most one
                                  onAccept: @escaping @MainActor () -> Void,   // callback, after focus returned;
                                  onDismiss: @escaping @MainActor () -> Void)  // a later showOutcome withdraws it
}
@MainActor protocol CandidateChooser {   // adapter returns focus to the Bound Target's app before replying
    func presentChoice(among candidates: [Candidate], for target: BoundTarget,
                       reply: @escaping @MainActor (Candidate?) -> Void)   // nil = Esc / click-away
}
// Rules, injected as `PasteAttemptRules { narrowingPolicy: NarrowingPolicy, preCheck }`.
protocol PreCheck: Sendable {   // adapter: LocalPreChecks (Core), see pre-checks.md
    func refusal(for item: ClipboardItem, in target: BoundTarget) -> PreCheckRefusal?
    func screenedContext(of target: BoundTarget) -> ScreenedTargetContext  // pinned at ⌘⇧V, sent in every request
}
```

## Phases and transitions (`idle` → … → outcome shown → `idle`)
| phase | event | action → next phase |
|---|---|---|
| idle | ⌘⇧V, focus unreadable | Wake Wait: re-read every 50 ms, "Waking <App>…" at 150 ms → wakeWaiting ([wake-wait.md](wake-wait.md)) |
| wakeWaiting | focus resolves | continue as from idle with the Bound Target (rows below); outcome carries `wakeWait` |
| wakeWaiting | still unreadable at 3 s / readable, nothing editable / click | `.refused(.targetNotReady(app))` / `.refused(.noEditableTarget)` / `.cancelled` |
| idle | ⌘⇧V, no Active Item / no target / `PreCheck` refusal | `showOutcome(.refused(r))` → idle (no Jev, no write) |
| idle | ⌘⇧V, checks pass, copy holds no visible character | `showOutcome(.noSuitableMatch)` → idle, no call |
| idle | ⌘⇧V, checks pass | pin item+target; start 5 s deadline + 150 ms indicator timer; Narrowing step 1 → `evaluate` → deciding |
| wakeWaiting, deciding, retrying, choosing, delivering | ⌘⇧V | ignored (offeringDirectPaste: ends the offer, row below) |
| deciding | 150 ms timer | `showProcessing(onCancel:)` |
| deciding | `.rateLimited(d)`, now+d < deadline | `showRetrying`; schedule retry after d → retrying |
| deciding | `.rateLimited(d)`, now+d ≥ deadline | `.failed(.timedOut)` |
| retrying | retry timer | the same step's request again → deciding |
| deciding, retrying | deadline timer | `.failed(.timedOut)` |
| deciding, retrying | Esc (`onCancel`) | `.cancelled` |
| deciding | `.failed` | `.failed(.decisionUnavailable)` |
| deciding | `.tooLarge` (Jev refused the size) | `.failed(.tooLongForSmartPaste)` |
| deciding | `.answered`: a pick that is not an offered piece, verbatim, inside the current piece | `.failed(.invalidResult)` |
| deciding | `.answered`: a piece, or several choices disagree | next step (or follow-up) → `evaluate`, stays deciding; a one-character piece is final without a call |
| deciding | `.answered`: the current piece unchanged | stop clocks; that piece (the whole copy: outer line breaks stripped) → delivering |
| deciding | `.answered`: nothing fits, at any step | stop clocks; `showNoSuitableMatchOffer`; 8 s offer timer → offeringDirectPaste ([no-suitable-match-offer.md](no-suitable-match-offer.md)) |
| offeringDirectPaste | `onAccept` (Enter) | `deliver(withoutOuterLineBreaks(item))` → delivering, path `offer: .accepted` |
| offeringDirectPaste | `onDismiss` (Esc / click-away), ⌘⇧V, 8 s timer | `.noSuitableMatch`, path `offer: .dismissed / .timedOut` → idle |
| deciding | `.answered`: ask the user | stop clocks; `presentChoice` with the options Jev weighted, most likely first → choosing |
| choosing | reply `nil` | `.cancelled` |
| choosing | reply candidate | validate like Jev's pick (offered, verbatim; a whole copy stripped) → delivering |
| delivering | step start | `isStillFocused` false → `.failed(.targetChanged)`, clipboard untouched; else `snapshot`, `write` (mark own), `postPasteKeystroke`, schedule 120 ms |
| delivering | Esc | ignored |
| delivering | 120 ms, `changeCount` == own write | `restore` (mark own) → `.inserted` |
| delivering | 120 ms, `changeCount` changed | skip restore → `.insertedWithoutRestore` (capture already made the foreign copy Active) |

Every outcome cancels all timers of the attempt, then `showOutcome` (with the attempt's path) and → idle.
Active Item is never changed by the coordinator; a copy during the attempt reaches `CopyCapture` and becomes Active there.

## Clocks
- **3 s Wake Wait limit**: starts at ⌘⇧V when the focus is unreadable; ends when it resolves (then the 5 s
  deadline starts) or at the limit. Re-reads every 50 ms; the 150 ms indicator shows "Waking <App>…" meanwhile.
- **5 s deadline**: starts when the Bound Target is resolved and the pre-checks pass (after any Wake Wait); covers every Narrowing step's call, every chooser-fill call and 429 back-off; a retry is
  scheduled only if it starts before the deadline. Stops at: chooser or No Suitable Match offer opens (both off it),
  delivery starts (delivery is uninterruptible), or any outcome. Not restarted after the chooser.
- **150 ms indicator**: same start (at ⌘⇧V during a Wake Wait; if "Waking…" was shown, processing replaces it at once); cancelled by any earlier outcome/chooser/delivery.
- **8 s No Suitable Match offer**: starts when the offer shows; Enter (delivery) or any outcome cancels it.
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
