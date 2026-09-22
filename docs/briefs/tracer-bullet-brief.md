# Brief — Tracer bullet: first end-to-end smart paste (issue #24)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/tracer-bullet`, branch `tracer-bullet` (forked from `main` at 95fb96a). Your supervisor
is the Pi session with intercom id **`01a0cac3`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use
exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks through the supervisor. One other worker
runs in parallel on the SQLite history slice — do not touch `Sources/HistoryStore`, `Tests/HistoryStoreTests` or
`Sources/SmartPasteCore/Seams/HistoryRepository.swift`.

Communication protocol:
- `intercom send 01a0cac3` one line after every numbered step: `[tracer] step N done — <fact>`.
- `intercom ask 01a0cac3` (blocking) at each **GATE**; prefix the message with `[tracer]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 24` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. `gh api repos/DanielMulec/jevpaste/issues/comments/5782480932 --jq .body` — the **state-machine report**:
   port shapes, obligations, and open question 3 (the shell adapters you now build).
3. `gh api repos/DanielMulec/jevpaste/issues/comments/5783177392 --jq .body` — the **MacInterop report**: the
   hotkey fires on V-release, only ⌘V is posted, `AdapterProbe.swift` shows how the real adapters are driven.
4. `gh api repos/DanielMulec/jevpaste/issues/comments/5782969127 --jq .body` — the JevGateway report (the live
   call takes ~1.2 s cold; `GatewayCredentials.standard.hasAPIKey` tells you whether the key file is readable).
5. `gh issue view 8 --comments` — the lifecycle resolution: 150 ms indicator, 5 s clock, ✓ on success, reason on
   failure, Esc cancels **only on our UI**, ⌘⇧V is the retry. Do not re-decide anything in it.
6. The sources: `Sources/SmartPasteCore/Seams/*.swift`, `Sources/SmartPasteCore/PasteAttempt/*.swift`,
   `Sources/SmartPasteCore/Capture/CopyCapture.swift`, `Sources/JevPasteApp/*.swift`, `docs/design/*.md`.
7. `gh issue view 16 --comments` (slice plan + acceptance), `gh issue view 1` **Notes** (hard rules: 400 lines/file
   incl. tests; no secrets in source; no payloads in diagnostic logs; verbatim excerpt only; refer to issues by
   title), `CONTEXT.md` (vocabulary), `docs/quality-gate.md`, `docs/signing.md`, `Makefile`, `scripts/make-app.sh`.
8. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
9. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. `make check` green before every commit.
- ≤ 400 lines per file, split by concern. Descriptive names from the glossary. No new dependencies without `ask`.
- Do not change Core ports. If a port shape truly cannot work, `ask` before touching Core.
- Commit small on `tracer-bullet`; push after each gate. Do not merge.

## Scope
`Sources/JevPasteApp/` (+ a test target for it if you add one — see below). Wire the real adapters into the
`PasteAttemptCoordinator` so one ⌘⇧V performs one real smart paste:

| port | adapter |
|---|---|
| `Hotkey`, `Clipboard`, `TargetResolver`, `Inserter` | `MacInterop` (`GlobalHotkey`, `SystemClipboard`, `AccessibilityTargetResolver`, `PasteKeystrokeInserter`) |
| `DecisionService` | `JevGatewayDecisionService()` |
| `CandidateExtraction` | `StructuralCandidateExtraction()` |
| `PreCheck` | **stub in the shell**: allow-all (`nil`), except refuse `.suspectedSecret` when `item.isConcealed` and `.secureField` when `target.isSecureField`. Real rules come with "Implement Pre-check rules". |
| `HistoryRepository` | **stub in the shell**: a no-op `record`. Persistent history comes with the next slice. |
| `CandidateChooser` | **stub in the shell**: replies `nil` immediately (outcome `.cancelled`, shown as "Several matches — chooser not built yet" or similar). The real chooser is its own slice; the tracer bullet must never guess among alternatives. |
| `PasteAttemptClock` | **real, yours**: `now` from `ContinuousClock`; `schedule` = one-shot `Timer` on the main run loop in `.common` modes (see `TimerPollingSchedule` in MacInterop for the pattern); `cancel` invalidates. |
| `PasteOutcomePresenter` | **real, yours**: see below. |

Active Item = whatever Daniel copies after launch (`CopyCapture` observes the clipboard through `SystemClipboard`).
The clipboard contents present *before* launch are not seeded; record that as an open question for the
capture+history slice, do not solve it here.

### Presenter requirements (from the lifecycle resolution)
- Non-focus-stealing: nothing you show may take key focus away from the Target. A non-activating `NSPanel`
  (`.nonactivatingPanel`, floating level, no activation) and/or the status item are the tools.
- Processing: visible by 150 ms after ⌘⇧V (Core calls `showProcessing` at that time; you only need to render
  promptly — do not schedule work that needs the main loop to turn during delivery).
- Retrying: a visibly different state ("Jev asked us to wait…").
- Outcome: ✓ for ~1 s on `.inserted`; a short reason for every other outcome (No Suitable Match, each refusal,
  each failure, cancelled, inserted-without-restore note), visible ~2.5 s; then back to idle. Every outcome
  must be visible — never silent.
- `onCancel`: Esc is only honoured on **our** UI. The processing indicator is never key, so Esc cannot reach it;
  therefore no global key monitor. Offer cancel as a click on the indicator and/or a "Cancel" menu item. Say
  which in the design doc.
- Status item menu keeps "Quit"; add nothing that needs a decision.
- Diagnostic logging (`os.Logger`, subsystem `jevpaste`): phase transitions and outcomes only; never the
  clipboard text, Candidates, Target Context or the Paste Result.

### Tests
Executable targets can be tested with `@testable import JevPasteApp` from a `Tests/JevPasteAppTests` target
(add it to `Package.swift` and check Periphery/SwiftLint still pass). Unit-test what is deterministic: the
clock (schedule/cancel on a spun run loop), the outcome → text/duration mapping, the stubs' behaviour. AppKit
rendering and the real paste are proven by the live run. Keep the `--probe` mode; the multi-line prototype
ticket will use it.

## Steps
1. `docs/design/app-shell.md` (≤ 100 lines): composition root, each shell adapter (mechanism, threading, what is
   unit-tested vs live-proven), the presenter's states and timings, the cancel affordance, and the live-run plan.
   **GATE A**: ask with the path.
2. Implement TDD; wire the composition root in `MenuBarDelegate` (or a new `SmartPasteApplication` type — keep
   `MenuBarDelegate` small).
3. Live run — **ask first, every time**: `make install` overwrites `~/Applications/JevPaste.app` (the
   Accessibility grant survives because of the `jevpaste-dev` identity; verify `AXIsProcessTrusted()` at launch
   and log it). Launch it. Then Daniel: copies a synthetic multi-field text (you propose it — e.g. a fake
   signature with one name, one email, one phone, no two of the same type), focuses a Chrome `data:` textarea
   with a label/placeholder that asks for one of those fields, presses ⌘⇧V, and answers `done`/`nothing`/`failed`
   with what he saw. Proof = the right excerpt inserted, ✓ shown, original clipboard restored (Daniel presses
   ordinary ⌘V afterwards and sees the synthetic original), nothing sent. Then one deliberately failing case
   (e.g. focus a non-editable element → visible refusal). Quit the app when done (ask before leaving it running).

## Final steps (after the slice steps above)
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files,
  and the proof evidence named above.
- Post a report comment on issue #24: what was built, test count, proof evidence, deviations, open questions
  (include: pre-launch clipboard not seeded; Jev cancel token still absent; anything the live run showed).
  **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`[tracer] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
