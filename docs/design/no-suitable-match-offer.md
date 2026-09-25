# No Suitable Match offer — Enter pastes everything

Slice: [Offer Enter to paste everything after No Suitable Match](https://github.com/DanielMulec/jevpaste/issues/42).
Decision: item 2 of [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35#issuecomment-5821465655).
Never automatic: the map rule "no automatic unmodified-source fallback" stands; Enter is a deliberate second act.

## Phase (Core) — `offeringDirectPaste`, off the clock like `choosing`
| phase | event | action → next phase |
|---|---|---|
| deciding | `.noneOfThese` / probability < 0.5, whole-item text exists | stop clocks; `showNoSuitableMatchOffer`; schedule 8 s → offeringDirectPaste |
| offeringDirectPaste | `onAccept` (Enter, focus back in the Target's app) | `deliver(wholeItemText)` → delivering (Bound Target re-verified there) |
| offeringDirectPaste | `onDismiss` (Esc / click-away), ⌘⇧V, 8 s offer timer | `.noSuitableMatch` → idle, nothing inserted |
Pre-checks are **not** re-run: they passed at ⌘⇧V for the same pinned item and Target. A reply after the attempt
ended is dropped by the attempt number and the phase check. ⌘⇧V during the offer only ends it (no new attempt
starts — one press, one act; press again). Whitespace-only item (no whole-item text): plain `.noSuitableMatch`.
Text: `DirectPasteRule` splits into `wholeItemText(of:)` (outer line breaks stripped, `nil` if blank) and the
single-line check that calls it — one implementation (note for #41: the Free-text Target needs the same function).

## Port — one method on `PasteOutcomePresenter`
`showNoSuitableMatchOffer(for target: BoundTarget, onAccept: @MainActor () -> Void, onDismiss: @MainActor () -> Void)`.
Adapter contract (as the chooser): at most one callback, sent after focus is back in the Bound Target's app; a later
`showOutcome` withdraws the offer without a callback. No new port in `PasteAttemptPorts`; fakes: `FakePresenter` only.

## Log — the offer's end rides on `SmartPastePath` (diagnostics only)
New case `SmartPastePath.noSuitableMatchOffer(NoSuitableMatchOfferEnd)`, `NoSuitableMatchOfferEnd { accepted,
dismissed, timedOut }` (⌘⇧V counts as dismissed). `RunningAttempt` keeps `offerEnd`; `finish` prefers it over
`RunningAttempt.path` (which #41 owns; untouched). Shell renders the fragment: `outcome inserted via=directPaste
reason=enterAfterNoMatch`, `outcome failed.targetChanged via=directPaste reason=enterAfterNoMatch`,
`outcome noSuitableMatch via=jev offer=dismissed|timedOut`. Not a `PasteAttemptNote`: notes are visible text.

## Shell — the indicator takes key focus for one key, reusing the chooser mechanism
Shows `questionmark.circle` **"No suitable match — press Enter to paste everything"** on the indicator panel, which
becomes key (non-activating) while offering, so Enter reaches us and never the Target. Extracted from the chooser:
- `PanelKeyView` + `PanelKey { moveUp, moveDown, confirm, escape }` (AppKit, from `ChooserKeyView`): the first
  responder both panels install. `StatusItemPanel.becomesKey` becomes settable; the indicator is key only offering.
- `KeyPanelSession<Answer>` (logic, from `PanelCandidateChooser.answer`/`logFocusReturn`): one open session per
  panel; ends before the panel closes (our own resign-key is ignored), returns focus via `TargetAppFocusReturn`,
  logs the result, replies once; `abandon()` = close + focus return, no reply (Core's timeout / ⌘⇧V).
- Keys while offering: Return/Enter accept, Esc dismiss, resign key = click-away; ↑/↓ and clicks inert.
  `IndicatorSurface` gains `offer(_:)` (display + take key) and `forwardOfferKeys(to:)`; `IndicatorNoticeSurface`
  treats an offer as a presenter display. Log (`PasteAttempt`): `offer shown`, `offer accepted|dismissed (esc|click-away)`.

## Timeout — `PasteAttemptCoordinator.noSuitableMatchOfferTimeLimit = .seconds(8)`
Long enough to read one line and press a key; short enough not to hold key focus for long. Core's clock.

## Tests
Core (`NoSuitableMatchOfferTests`, fakes): noneOfThese and p < 0.5 show the offer with the Bound Target, no outcome,
5 s clock stopped; Enter delivers the whole item (outer breaks stripped) → `.inserted`, path accepted; Esc → nothing
written, `.noSuitableMatch` dismissed; 8 s → timedOut, not at 7.9 s; late Enter after timeout ignored; ⌘⇧V
dismisses, no Jev request; Target changed → `.failed(.targetChanged)`; note still carried. `DirectPasteRuleTests`:
`wholeItemText`. Four existing tests add one `presenter.dismissOffer()` line. App: `KeyPanelSession` (reply once
after focus, abandon, second answer ignored), presenter offer (text, key taken, Enter/Esc/click-away callbacks,
`showOutcome` withdraws without callback), log fragments; chooser tests unchanged and green.

## Live run (after the install gate; payload `JEVPASTE-ENTER-ONE` / `JEVPASTE-ENTER-TWO`, Chrome `data:` *Phone*)
a. ⌘⇧V → offer text → **Esc** → field empty, `noSuitableMatch via=jev offer=dismissed`. Why: nothing without Enter.
b. ⌘⇧V → offer → wait 9 s → field empty, `offer=timedOut`. Why: the offer does not sit, nothing inserted on its own.
c. ⌘⇧V → offer → **Enter** → both lines in the field (flattened by the input), `via=directPaste
   reason=enterAfterNoMatch`, clipboard = payload again. Why: the rescue works; Enter never reached Chrome.
d. Labelled *Email* field + a matching two-line payload → ordinary excerpt ✓. Why: the Jev path is unchanged.
Chrome via DevTools MCP; Esc/Enter posted by Daniel unless our panel is provably key.
