# Handoff — Candidate Chooser UI (issue #26)

For a fresh worker continuing [Implement the Candidate Chooser UI](https://github.com/DanielMulec/jevpaste/issues/26).
Read with: `docs/design/candidate-chooser.md` (design), `docs/briefs/candidate-chooser-brief.md` (original brief),
the report and addendum on the issue (`gh issue view 26 --comments`). Supervisor: intercom id `01a0cc6f`.

## 1. Branch and commits
Worktree `~/.pi/worktrees/jevpaste/candidate-chooser`, branch `candidate-chooser`, forked from `main` 0ef117e.
Pushed, **not merged**. `make check` passes (247 tests in 45 suites) at the head before this handoff commit.
| sha | what |
|---|---|
| `04ff640` | design doc `docs/design/candidate-chooser.md` (GATE A approved) |
| `32a4756` | chooser panel + adapter + focus return + tests; placement and panel parts extracted from `IndicatorPanel`; `hideWhileChoosing`; interim chooser removed; `app-shell.md` chooser row |
| `f9eff60` | design doc records the live-proven activation path (no `NSApp.activate` fallback) |
| `d10a878` | review fixes: decline a second choice, re-entry test, no beep on unknown keys, `timeInterval` for log ms, auto-hide test |
| (this) | this handoff |

## 2. Architecture (`Sources/JevPasteApp/Chooser/`) and why
- **Seam** `ChooserSurface` (+ `ChooserEvent`: `moveUp`, `moveDown`, `chooseSelected`, `choose(row:)`,
  `cancel(.escape | .clickAway)`) in `ChooserSurface.swift`. It keeps all logic testable without AppKit, like
  `IndicatorSurface`. Test fake: `Tests/JevPasteAppTests/ChooserTestDoubles.swift`.
- **`ChooserContent`**: pure; title “Which one for “<fieldLabel>”?” → placeholder → “Which one?”; one row per
  Candidate in Core's order; multi-line → `<first line> … N lines`. **Display only**: the reply is always the
  `Candidate` value Core passed in (hard rule: the Paste Result is verbatim; the chooser never edits).
- **`PanelCandidateChooser`** (the `CandidateChooser` adapter; holds the selection model):
  - `presentChoice` hides the indicator (`hideWhileChoosing`), opens the surface with row 0 selected.
  - ↑/↓ clamp at the ends (no wrap). Enter / row click choose; Esc / click-away cancel.
  - **Reply-once**: `answer` sets `openChoice = nil` *before* `surface.close()` (so the resign-key our own close
    causes is ignored) and before `reply` (so a reply that synchronously opens the next choice finds it free).
  - **Decline-newcomer**: `presentChoice` while a choice is open replies `nil` to the *new* caller at once and leaves
    the open one untouched. Unreachable via Core (one attempt at a time); chosen so every caller gets one reply and no
    stale `nil` reaches Core's still-`choosing` attempt.
  - Logs (category `CandidateChooser`, counts/indices only): opened with N, chose index i, cancelled (esc|click-away),
    target app reactivated in X ms / not frontmost after X ms / gone.
- **`TargetAppFocusReturn`** over `ApplicationActivator` (prod: `WorkspaceApplicationActivator` —
  `NSRunningApplication(processIdentifier:)`, `NSApp.yieldActivation`, `activate()`; `frontmostApplication`):
  activate, check at once, then poll every 10 ms on the `PasteAttemptClock`, bound 1 s → completion once with
  `frontmost / notFrontmost / appGone`. The chooser replies in that completion on choose **and** cancel. After the
  bound it replies anyway; Core's Bound Target re-verification refuses ("Target changed") if focus is elsewhere.
  Poll, not `didActivateApplicationNotification`: with a non-activating panel the Target app usually never stopped
  being active (live: 0 ms), so no notification would come.
- **`ChooserPanel` / `ChooserRowView`** (AppKit, live-proven only): `StatusItemPanel(becomesKey: true)` —
  `.nonactivatingPanel`, `canBecomeKey` true, `canBecomeMain` false, `makeKeyAndOrderFront`; key handling in the
  first-responder view's `keyDown` (no global monitor); `resignKey` → click-away. Placed below the status item.
- **Shared, extracted from `IndicatorPanel`** (behaviour-identical, approved): `StatusItemPlacement.swift` (origin
  below the status item clamped to its screen; pure part unit-tested) and `StatusItemPanelParts.swift`
  (`StatusItemPanel(becomesKey:)`, `HUDBackgroundView`, `FirstClickView`, `NSView.addFillingSubview`). Needed because
  jscpd (threshold 0 %) flagged the copies.
- **`IndicatorPresenter.hideWhileChoosing()`** (GATE A option A): drops `onCancel` and any pending hide, hides the
  surface, state → hidden; Core's later `showOutcome` renders normally. Otherwise "Jev is choosing… click to cancel"
  (inert while choosing) stayed visible where the chooser opens.
- Composition root: `SmartPasteApplication` gained a shared `statusItemFrame` closure and the `chooser:` wiring only.

## 3. Review (GPT-6-Sol, `~/.pi/worktrees/jevpaste/review-chooser/REVIEW-BRIEF.md`) → verdict fix
- BLOCKING stale `nil` / re-entry overwrite in `presentChoice` → **fixed** `d10a878` (decline-newcomer + 2 tests).
- Unknown keys went to `super.keyDown` (beep) → **fixed** (ignored).
- `wholeMilliseconds` duplicated Core's `Duration.timeInterval` → **fixed** (removed).
- Missing test: armed auto-hide + `hideWhileChoosing` + later outcome → **added**.
- Focus-return `[weak self]` teardown → **declined** (supervisor), open question below.
- CRLF/lone-CR line counting in `ChooserContent` → **declined** (supervisor), open question below.
- Not asserted by tests: close-triggered resign-key synchronously, Enter+click in one turn, close-before-reply order.

## 4. Merge touchpoints with `capture-history` (origin head seen: `d49d87b`)
- `SmartPasteApplication.swift`: both branches edit the init. Theirs: `presenter` wraps `HistoryNoticeSurface(wrapping:
  panel, clock:)` and changes the `capture` lines. Ours: `IndicatorPanel { … }` became `let statusItemFrame = …` +
  `IndicatorPanel(anchorFrame: statusItemFrame)`, and the `chooser:` line. Textual conflict near the panel/presenter
  lines; resolve by keeping both (their `notices` decorator, our `statusItemFrame` + `ChooserPanel(anchorFrame:)`).
- `docs/design/app-shell.md`: they edit the history row and Active Item bullet; we replaced the
  `UnbuiltCandidateChooser` row. Keep both. Also the prose "(or "Several matches — chooser not built yet" …)" in the
  Presenter section is now stale — fix on merge.
- **Semantic**: `hideWhileChoosing()` → `surface.hide()` goes through `HistoryNoticeSurface.hide()`, which then
  **displays a waiting history notice immediately** — in the indicator panel at the same spot as the chooser, while
  the chooser is open. Not proven live. Recommendation: merge chooser after capture-history, then check live; if the
  notice overlaps the chooser, keep the notice waiting while choosing (e.g. a decorator/presenter signal "choosing"
  instead of a plain hide) — ask the supervisor first, it touches both slices' files.

## 5. Open questions and live-proof gaps
1. **Esc and click-away cancellation unproven live.** 2. Chooser **title text unconfirmed** (does AX give
   "Email address" as `fieldLabel`?). 3. `TargetAppFocusReturn` poll captures `self` weakly: if deallocated mid-poll,
   the reply is never sent (unreachable in prod — app-lifetime ownership). 4. `ChooserContent` line count for lone
   `\r` / other newline forms not tested (CRLF is). 5. Indicator still says "click to cancel" during the ≤ 150 ms
   delivery (hardening). 6. Live regression check of the indicator's click-to-cancel after the panel-parts extraction.

Live steps still to do (ask the supervisor for "go" first; the installed app is shared):
1. `make install`, `open ~/Applications/JevPaste.app`; log shows `accessibilityTrusted=true apiKeyPresent=true`.
2. Write the synthetic signature to `/tmp/jevpaste-chooser.txt` (`Maren Holtby` / `Work: maren.holtby@example.org` /
   `Private: maren.h@example.net` / `Phone: +49 30 5550 1234`), `open -e` it; Daniel does ⌘A ⌘C himself.
3. `open -a "Google Chrome" 'data:text/html,<label for=e>Email address</label><br><textarea id=e rows=4 cols=40></textarea>'`.
4. Daniel: click textarea, ⌘⇧V → report exact title; **Esc** → "Cancelled", then type a letter → lands in textarea.
5. Daniel: ⌘⇧V → **click into the Chrome page** → "Cancelled", nothing inserted.
6. Read `log show --last 10m --predicate 'subsystem == "jevpaste"' --style compact` (expect `cancelled (esc)`,
   `cancelled (click-away)`, `target app reactivated in … ms`, `outcome cancelled`); quit the app; report on #26.
One `intercom ask 01a0cc6f` per step needing Daniel.

## 6. Do not
- Merge, or `make install` without the supervisor's go. Change Core (`Sources/SmartPasteCore`) without asking.
- Touch `Interim/DiscardingHistoryRepository.swift`, `Sources/SmartPasteCore/Capture/` (capture worker's).
- Put Candidate text, titles, labels, context or clipboard contents in logs, commits or reports; copy to Daniel's
  clipboard for him; print `~/.config/jevpaste/env`.
- Reply from the chooser before focus return completes, or reply with row text instead of the original `Candidate`.
- Exceed 400 lines per file; skip `make check` before commits (run one plain `swift build` in a fresh worktree first).

## Suggested skills (under `~/.agents/skills/` unless noted)
- `tdd` — any fix (e.g. keeping a history notice waiting while choosing) goes red → green at the agreed seams.
- `codebase-design` — before moving the choosing signal between presenter and `HistoryNoticeSurface` (seam placement).
- `resolving-merge-conflicts` — the `SmartPasteApplication.swift` / `app-shell.md` conflicts with `capture-history`.
- `pi-intercom` (pi-intercom package) — supervisor protocol: `send` per step, `ask` at gates and before `make install`.
- `diagnosing-bugs` — if Esc/click-away fails live (e.g. resign-key not firing, focus not returning).
- `prototype` — only if a throwaway AppKit probe is needed to isolate key/resign-key behaviour outside the app.

Links: report https://github.com/DanielMulec/jevpaste/issues/26#issuecomment-5789291286 · addendum
https://github.com/DanielMulec/jevpaste/issues/26#issuecomment-5789338604 · lifecycle
[issue 8](https://github.com/DanielMulec/jevpaste/issues/8) · capture branch design `docs/design/capture-and-history.md`
(on `capture-history`).
