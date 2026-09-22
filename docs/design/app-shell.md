# App shell — tracer bullet (first end-to-end Smart Paste)

Slice: [Tracer bullet: first end-to-end smart paste](https://github.com/DanielMulec/jevpaste/issues/24).
Lifecycle: [Choose paste lifecycle, cancellation and clipboard preservation](https://github.com/DanielMulec/jevpaste/issues/8).
Core ports are unchanged (`docs/design/paste-attempt-state-machine.md`). Everything below is in `Sources/JevPasteApp`.

## Composition root — `SmartPasteApplication`
- `@MainActor final class`, created by `MenuBarDelegate.applicationDidFinishLaunching` after the status item is
  set up. `MenuBarDelegate` still owns only the status item and its "Quit" menu. `--probe` stays as it is.
- It builds and keeps: `SystemClipboard()` (100 ms polling), `CopyCapture(clipboard:history:)`, and
  `PasteAttemptCoordinator` with `GlobalHotkey()`, `AccessibilityTargetResolver()`, `PasteKeystrokeInserter()`,
  `JevGatewayDecisionService()`, `RunLoopPasteAttemptClock`, `IndicatorPresenter`, `UnbuiltCandidateChooser`,
  plus rules `StructuralCandidateExtraction()` and `SecureTargetAndConcealedItemPreCheck`.
- At launch it logs `AXIsProcessTrusted()` and `GatewayCredentials.standard.hasAPIKey` (booleans only).
- Active Item = the first copy after launch. Clipboard contents present before launch are not seeded
  (open question for the capture+history slice). Until then ⌘⇧V shows "Nothing copied yet".

## Shell adapters
| adapter | port | mechanism | tested |
|---|---|---|---|
| `RunLoopPasteAttemptClock` | `PasteAttemptClock` | `now` = `ContinuousClock.now`; `schedule` = one-shot `Timer` added to `RunLoop.main` in `.common` modes (as `TimerPollingSchedule`), action via `MainActor.assumeIsolated`; the returned `ScheduledAction` invalidates the timer | unit: fires once after the delay on a spun main run loop; not before; cancelled never fires |
| `SecureTargetAndConcealedItemPreCheck` | `PreCheck` | `.secureField` if `target.isSecureField`, else `.suspectedSecret` if `item.isConcealed`, else `nil`. Replaced by "Implement Pre-check rules" | unit: all four combinations |
| `DiscardingHistoryRepository` | `HistoryRepository` | `record` does nothing. Replaced by the capture+history slice | none (no behaviour) |
| `UnbuiltCandidateChooser` | `CandidateChooser` | tells the presenter the next `.cancelled` means "chooser not built", then replies `nil` synchronously → Core finishes `.cancelled`. Never guesses | unit: replies `nil` once; the outcome text is the chooser one; a later plain cancel reads "Cancelled" |
| `IndicatorPresenter` | `PasteOutcomePresenter` | see below | unit: state/timing logic over a fake panel and a manual clock |

All shell types are `@MainActor` (AppKit, timers). Nothing blocks the main actor; Jev replies arrive via Core's
`@MainActor` reply closure.

## Presenter
Split so the logic is testable without AppKit:
- `OutcomeMessage` (pure): `PasteAttemptOutcome` → symbol, short text, display duration.
- `IndicatorPresenter` (logic): holds the state (`hidden`, `processing`, `retrying`, `outcome`), the pending
  `onCancel`, the auto-hide `ScheduledAction` (on the injected `PasteAttemptClock`), and renders through an
  `IndicatorSurface` protocol. Logs phase transitions and outcome *kinds* (`os.Logger`, subsystem `jevpaste`,
  category `PasteAttempt`, `privacy: .public` on enum names only) — never clipboard text, Candidates, Target Context
  or the Paste Result.
- `IndicatorPanel` (AppKit, `IndicatorSurface`): one reused `NSPanel` subclass, `[.nonactivatingPanel,
  .borderless]`, `.floating` level, `canBecomeKey`/`canBecomeMain` = `false`, `hidesOnDeactivate = false`,
  `collectionBehavior` `.canJoinAllSpaces` + `.fullScreenAuxiliary`, shown with `orderFrontRegardless()` (never
  `makeKey`, never `NSApp.activate`). Placed just below the status item button (fallback: top-right of the main
  screen). Content: an SF Symbol + one line of text. A click (`acceptsFirstMouse` = true) is forwarded to the presenter.

States and timings:
| call | shows | ends |
|---|---|---|
| `showProcessing(onCancel:)` (Core calls it at 150 ms) | `ellipsis.circle` "Jev is choosing… click to cancel" | next call |
| `showRetrying()` | `hourglass` "Jev asked us to wait… click to cancel" | next call |
| `showOutcome(.inserted)` | `checkmark.circle.fill` "Pasted" | hidden after 1 s |
| `showOutcome(other)` | symbol + reason (table below) | hidden after 2.5 s |

The "click to cancel" hint appears only once Core has handed over `onCancel`; a 429 before 150 ms shows the
retrying label without it, and the later `showProcessing` re-displays retrying with the hint.

Reasons: `.insertedWithoutRestore` "Pasted — original clipboard not restored (replaced by your new copy)";
`.noSuitableMatch` "No suitable match"; refusals "Nothing copied yet" / "No text field focused" / "Secure field —
not supported" / "Suspected secret — blocked"; `.cancelled` "Cancelled" (or "Several matches — chooser not built
yet" after the chooser stub); failures "Jev took longer than 5 s" / "Jev unavailable" / "Jev's answer was not an
exact excerpt" / "Target changed — nothing pasted". Every outcome is shown; a new attempt cancels a pending hide.
Outcomes that end before 150 ms (refusals) show only the outcome, never the processing state.

Rendering is prompt: each call sets the content and orders the panel front synchronously; nothing waits for the
main loop to turn during delivery (delivery itself no longer blocks).

## Cancel affordance
A **click on the indicator panel** while it shows processing or retrying calls `onCancel`. Clicks in any other
state are ignored. No global key monitor, no Esc (the panel is never key, so Esc cannot reach it), no menu item.

## Tests (`Tests/JevPasteAppTests`, `@testable import JevPasteApp`)
Added to `Package.swift`; Periphery and SwiftLint rerun. Deterministic: clock on a spun run loop, `OutcomeMessage`
mapping and durations, presenter state/auto-hide/cancel over a fake surface + manual clock, the stubs.
Live-proven only: the panel's rendering and non-activation, hotkey → real paste, Jev call, restore.

## Live-run plan (step 3; ask before each `make install` and launch)
1. `make install`, `open ~/Applications/JevPaste.app`; read `log show --predicate 'subsystem == "jevpaste"'` for
   `accessibilityTrusted=true`, `apiKeyPresent=true`.
2. Daniel copies (from a text editor):
   `Maren Holtby` / `maren.holtby@example.org` / `+49 30 5550 1234` — three lines, one of each kind.
3. Daniel opens `data:text/html,<label for=e>Email address</label><br><textarea id=e placeholder="Your email
   address" rows=4 cols=40></textarea>` in Chrome, clicks into the textarea, presses ⌘⇧V.
   Expected: processing indicator, then "✓ Pasted"; textarea holds exactly `maren.holtby@example.org`, no newline.
4. After the ✓ has disappeared, Daniel presses ordinary ⌘V in the textarea: the full three-line synthetic text appears (clipboard restored).
5. Failing case: Daniel clicks the Finder desktop (nothing editable focused), presses ⌘⇧V → "No text field focused".
   If the desktop resolves as editable, a Chrome page with no field focused instead (reported).
6. Evidence: Daniel's `done`/`nothing`/`failed` report plus the `jevpaste` log lines (kinds only). Then I quit the app.

## Open questions (carried into the report)
Pre-launch clipboard not seeded; `DecisionService` cancel token still absent (a cancelled request still runs);
no Jev pre-warm at launch (cold call ~1.2 s).
The label still says "click to cancel" during the ≤ 150 ms delivery step, where a click has no effect (Core has no
port call at delivery start) — for the hardening slice.
