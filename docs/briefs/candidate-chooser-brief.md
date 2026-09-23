# Brief — Implement the Candidate Chooser UI (issue #26)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/candidate-chooser`, branch `candidate-chooser` (forked from `main`). Your supervisor is
the Pi session with intercom id **`01a0cc6f`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use
exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks through the supervisor. **One other
worker runs in parallel on clipboard capture + persistent history** — see "Shared files" below.

Communication protocol:
- `intercom send 01a0cc6f` one line after every numbered step: `[chooser] step N done — <fact>`.
- `intercom ask 01a0cc6f` (blocking) at each **GATE**; prefix the message with `[chooser]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 26` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. `gh issue view 8 --comments` — the lifecycle resolution: the chooser is **off the 5 s clock**; Esc or
   click-away cancels; choosing re-activates the Bound Target's app and proceeds to atomic delivery (Core
   re-verifies the Target). Do not re-decide anything in it.
3. `gh api repos/DanielMulec/jevpaste/issues/comments/5782480932 --jq .body` — the **state-machine report**
   (the `CandidateChooser` port: `presentChoice(among:for:reply:)`, reply once, `nil` = Esc/click-away; the
   adapter returns focus to the Bound Target's app **before** replying).
4. `gh api repos/DanielMulec/jevpaste/issues/comments/5783953394 --jq .body` — the **tracer-bullet report**
   (the shell you extend; the interim `UnbuiltCandidateChooser` you remove).
5. `gh issue view 7 --comments` — when the chooser opens: local same-type alternatives (≥ 2), never Jev confidence.
6. The sources: `Sources/SmartPasteCore/Seams/CandidateChooser.swift`, `Sources/SmartPasteCore/Values/*.swift`
   (`Candidate`, `BoundTarget`, `TargetIdentity.processIdentifier`), `Sources/SmartPasteCore/PasteAttempt/
   PasteAttemptCoordinator+Decision.swift`, `Sources/SmartPasteCore/Candidates/StructuralCandidateExtraction.swift`,
   `Sources/JevPasteApp/**/*.swift` (esp. `Indicator/IndicatorPanel.swift` — the non-activating panel pattern),
   `Sources/MacInterop/AccessibilityTargetResolver.swift`, `docs/design/app-shell.md`,
   `docs/design/paste-attempt-state-machine.md`.
7. `gh issue view 16 --comments` (slice plan + acceptance), `gh issue view 1` **Notes** (hard rules: 400 lines/file
   incl. tests; **the Paste Result is one exact verbatim excerpt — the chooser displays, never edits**; no
   payloads in diagnostic logs; refer to issues by title), `CONTEXT.md`, `docs/quality-gate.md`, `Makefile`.
8. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
9. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. `make check` green before every commit.
- ≤ 400 lines per file, split by concern. Descriptive names from the glossary. No new dependencies without `ask`.
- **No Core changes.** If the port shape truly cannot work, `ask` before touching Core.
- Commit small on `candidate-chooser`; push after each gate. Do not merge.

## Shared files (parallel worker on capture + history)
The capture worker changes the `capture`/history lines of `SmartPasteApplication.swift`, replaces
`Interim/DiscardingHistoryRepository.swift`, adds files under `Sources/JevPasteApp/History/` (or similar) and a
new indicator file for history notices, and touches `CopyCapture.swift` in Core. You therefore:
- touch `SmartPasteApplication.swift` **only** on the `chooser:` line and what it needs; keep the diff minimal;
- in `Indicator/IndicatorPresenter.swift` and `Indicator/OutcomeMessage.swift` remove **only** the interim
  chooser lines (`explainNextCancellationAsChooserNotBuilt`, `cancellationIsChooserDecline`, `.chooserNotBuilt`)
  and their tests; change nothing else there;
- delete `Interim/UnbuiltCandidateChooser.swift` + `Tests/JevPasteAppTests/UnbuiltCandidateChooserTests.swift`;
  never touch `Interim/DiscardingHistoryRepository.swift` or `Sources/SmartPasteCore/Capture/`;
- put your code under `Sources/JevPasteApp/Chooser/`;
- `~/Applications/JevPaste.app` is shared: `make install` **only** when the supervisor's gate reply says go.

## Scope
A real `CandidateChooser` adapter in the shell:
- **When**: Core calls `presentChoice` with ≥ 2 same-type alternatives (you do not decide when; you render).
- **Look**: a small panel near the status item (or centred on the screen of the Target's app — say which and why
  in the design doc), titled from the Target's context when available ("Which one for “Email address”?", else
  "Which one?"), listing each Candidate's text **verbatim**. Multi-line Candidates (paragraphs, sections, whole
  item) are shown as their first line plus a line count ("… 4 lines") — display only; the reply is the untouched
  `Candidate`. Keep the order Core gave you.
- **Interaction**: ↑/↓ moves, Enter/click chooses, **Esc** cancels, **click-away** (the panel resigns key /
  the app deactivates) cancels. Reply exactly once; a second Esc/click after the reply is ignored. The panel must
  be **key** to receive keys — so it *does* take focus; that is why it must hand focus back.
- **Re-activation before reply**: on choose, close the panel, activate the Bound Target's app
  (`NSRunningApplication(processIdentifier: target.identity.processIdentifier)`), wait until it is frontmost
  (`NSWorkspace.didActivateApplicationNotification` or a short bounded poll — say which; bound it, e.g. 1 s, then
  reply anyway and let Core's re-verification refuse), **then** `reply(candidate)`. On cancel, close the panel,
  re-activate the app too (the user should land back where they were), then `reply(nil)`.
- The 5 s clock is already stopped by Core; the processing indicator: check what the presenter shows while the
  chooser is open (`showProcessing` may have been called) — hide or relabel it via the existing presenter API if
  it would read "Jev is choosing… click to cancel" under the chooser; `ask` if that needs a presenter change.
- Diagnostic logging: "chooser opened with N alternatives", "chose index i", "cancelled (esc|click-away)",
  "target app reactivated in X ms" — never Candidate text, labels or context.
- Remove the interim pieces listed under "Shared files". Update `docs/design/app-shell.md`'s adapter table row for
  the chooser (one line) — nothing else in that file.

### Tests (`Tests/JevPasteAppTests`)
Split so the logic is testable without AppKit, like the presenter: a `ChooserPresenter`/selection model
(candidates, selected index, move up/down with bounds, choose, cancel, reply-once guard, display rows incl. the
multi-line abbreviation) over a fake surface; the re-activation wait over a fake "app activator" with a manual
clock (activated promptly / never → bounded). AppKit panel, key handling and real focus return are live-proven.

## Steps
1. `docs/design/candidate-chooser.md` (≤ 100 lines): panel placement, key/activation behaviour, the re-activation
   wait and its bound, states, what is unit-tested vs live-proven, the live-run plan. **GATE A**: ask with the path.
2. Implement TDD.
3. Live run — **ask first** (the installed app is shared with the other worker): `make install`, launch. Daniel
   copies a synthetic signature with **two emails** (you propose it, e.g. name / work email / private email /
   phone), focuses a Chrome `data:` textarea labelled "Email address", presses ⌘⇧V → chooser appears; he picks
   the **second** with ↓ + Enter → inserted verbatim, ✓ shown, ordinary ⌘V afterwards restores the original.
   Then: ⌘⇧V again, Esc → "Cancelled", focus back in Chrome; ⌘⇧V again, click into Chrome → cancelled. Quit the
   app when done.

## Final steps
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files,
  and the proof evidence above.
- Post a report comment on issue #26: what was built, test count, proof evidence, deviations, open questions.
  **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`[chooser] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
