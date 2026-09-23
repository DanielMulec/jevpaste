# Candidate Chooser — shell adapter

Slice: [Implement the Candidate Chooser UI](https://github.com/DanielMulec/jevpaste/issues/26).
Lifecycle: [Choose paste lifecycle, cancellation and clipboard preservation](https://github.com/DanielMulec/jevpaste/issues/8).
Core is unchanged: Core calls `CandidateChooser.presentChoice(among:for:reply:)` with ≥ 2 same-type alternatives
(Core decides when), with its clocks already stopped. The adapter replies once — the untouched `Candidate`, or
`nil` for Esc / click-away — after focus is back in the Bound Target's app. Code: `Sources/JevPasteApp/Chooser/`.

## Placement — below the status item
The panel opens where the indicator sits (same anchor function, same screen clamping as `IndicatorPanel`).
Why not centred on the Target's screen: the shell only knows the Target's pid, not its window or screen (that would
need a new AX call or a Core change); the status item is where every jevpaste feedback appears, so the eye already
goes there after ⌘⇧V; and it never covers the Target field the user is looking at.

## Look
- Title: `Which one for “<fieldLabel>”?`, else `Which one for “<placeholder>”?`, else `Which one?`
  (from `BoundTarget.context`; long titles truncate at the tail in the panel — display only).
- One row per Candidate, **in Core's order**, text verbatim. A multi-line Candidate shows its first line followed by
  `… N lines` (N = number of lines of the whole Candidate). Long rows truncate at the tail visually. Display only:
  the reply is always the `Candidate` value Core passed in, never the row text.
- The selected row is highlighted; the first row is selected on open. Footer hint: `↑↓ Enter — Esc cancels`.

## Keys and activation
- A borderless `NSPanel` with `.nonactivatingPanel`, `canBecomeKey = true`, `canBecomeMain = false`, `.floating`,
  shown with `makeKeyAndOrderFront`. It becomes **key without activating jevpaste**, so it receives keys while the
  Target's app stays the active app. It still takes key focus from the Target's window — hence the focus return.
- Keys (in the panel's `keyDown`): ↑ / ↓ move the selection, clamped at the ends (no wrap); Return / Enter choose
  the selected row; Esc cancels. A click on a row chooses that row. Other keys are ignored.
- Click-away = the panel resigns key (`windowDidResignKey`: the user clicked another window or app) → cancel.
- Fallback, only if the live run shows keys do not arrive: additionally `NSApp.activate()` before
  `makeKey`, and treat `NSApplication.didResignActive` as click-away too (reported as a deviation).

## Focus return before reply — bounded poll
On choose **and** on cancel: mark the session answered, close the panel, `NSRunningApplication(processIdentifier:)
.activate()` for the Bound Target's pid, then poll `NSWorkspace.shared.frontmostApplication?.processIdentifier`
every **10 ms** on the injected `PasteAttemptClock` (the production run-loop clock), checking once immediately.
As soon as the pid is frontmost → `reply`. Bound: **1 s** — then reply anyway; Core's Bound Target re-verification
refuses with "Target changed" if focus is elsewhere. App gone (`NSRunningApplication` is `nil`) → reply at once.
Why polling, not `didActivateApplicationNotification`: with the non-activating panel the Target's app usually never
stopped being active, so no notification would arrive; a poll covers both cases, needs a timer for the bound anyway,
and is deterministic over a manual clock.

## States (one reused panel, one session at a time)
`closed` → `open(selectedIndex)` → `returningFocus` → `closed`. Only `open` reacts to keys, clicks and resign-key;
the transition out of `open` happens before the panel is ordered out, so the resign-key caused by our own close and
any late Esc/click are ignored → exactly one reply. A new `presentChoice` while a session is not `closed` ends the
old one silently with `nil` (Core's attempt-number guard drops it) — defensive only, Core never does this.

## The processing indicator under the chooser (decided at GATE A)
By the time Jev answered (> 150 ms) the indicator usually shows "Jev is choosing… click to cancel", inert in the
`choosing` phase. On open the chooser calls `IndicatorPresenter.hideWhileChoosing()` (state → hidden, `onCancel`
and any pending hide dropped, surface hidden); Core's later `showOutcome` displays as usual.

## Shared panel parts
`StatusItemPlacement` (origin below the status item, clamped to its screen; pure part unit-tested) and
`StatusItemPanelParts` (`StatusItemPanel(becomesKey:)`, `HUDBackgroundView`, `FirstClickView`) are used by both
`IndicatorPanel` and `ChooserPanel`, extracted from `IndicatorPanel` without behaviour change.

## Diagnostic logging (`os.Logger`, subsystem `jevpaste`, category `CandidateChooser`, enum/ints public)
`chooser opened with N alternatives`, `chose index i`, `cancelled (esc|click-away)`,
`target app reactivated in X ms` / `target app not frontmost after 1000 ms` / `target app gone`. Never Candidate
text, row text, titles, labels or context.

## Unit-tested vs live-proven
Unit (`Tests/JevPasteAppTests`, fakes + `SteppedClock`, no AppKit):
- `ChooserRow` display text: single line verbatim; multi-line → first line + `… N lines`; title fallbacks.
- `TargetAppFocusReturn`: frontmost at once / on a later poll / never (reply at 1 s, not before) / app gone.
- `PanelCandidateChooser` (the adapter; holds the selection model) over a fake `ChooserSurface` + fake `ApplicationActivator` + `SteppedClock`:
  opens with rows and title in Core's order, first row selected, indicator hidden; ↑/↓ clamped at both ends; replies with the untouched `Candidate`; Esc and click-away reply `nil`;
  reply comes only after the Target's app is frontmost; never frontmost → reply at 1 s, not before; app gone → reply
  at once; a second Esc/click after the reply is ignored; the surface is closed before the reply.
Live-proven only: the AppKit panel, key routing to a non-activating key panel, resign-key on click-away, real focus
return into Chrome, and the end-to-end paste.

## Removed interim pieces
`Interim/UnbuiltCandidateChooser.swift` + its tests; in `IndicatorPresenter`/`OutcomeMessage` only
`explainNextCancellationAsChooserNotBuilt`, `cancellationIsChooserDecline`, `.chooserNotBuilt` and their tests.
`SmartPasteApplication`: only the `chooser:` line (and the panel it needs). `app-shell.md`: the chooser table row.

## Live-run plan (step 3; ask before `make install`)
1. `make install`, launch; Daniel copies from a text editor (synthetic):
   `Maren Holtby` / `Work: maren.holtby@example.org` / `Private: maren.h@example.net` / `Phone: +49 30 5550 1234`.
2. Chrome `data:text/html,<label for=e>Email address</label><br><textarea id=e rows=4 cols=40></textarea>`,
   click into the textarea, ⌘⇧V → chooser "Which one for “Email address”?" with the two emails in that order.
3. ↓ + Enter → textarea holds exactly `maren.h@example.net`, ✓ "Pasted"; ordinary ⌘V then pastes the four lines.
4. ⌘⇧V, Esc → "Cancelled", typing lands in the textarea. 5. ⌘⇧V, click into Chrome → "Cancelled", nothing inserted.
6. Evidence: Daniel's report + `log show --predicate 'subsystem == "jevpaste"'` lines (kinds/ints only); quit app.
