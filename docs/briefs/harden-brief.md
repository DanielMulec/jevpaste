# Brief — Harden installation and daily use (issue #28)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/harden`, branch `harden` (forked from `main`). Your supervisor is the Pi session
with intercom id **`01a0cf8d`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly that id;
ignore any other pi in that cwd. Daniel (owner) speaks through the supervisor. **The supervisor is running a
live prototype with Daniel in parallel** — the installed app and Daniel's attention are shared; every live step
is gated (see "Live runs").

Communication protocol:
- `intercom send 01a0cf8d` one line after every numbered step: `[harden] step N done — <fact>`.
- `intercom ask 01a0cf8d` (blocking) at each **GATE**; prefix with `[harden]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 28 --comments` — your ticket (already assigned to Daniel; that is the claim, leave it).
   The **newest comment** is the consolidated inherited list — it is part of your scope.
2. `docs/handoffs/capture-history-HANDOFF.md` and `docs/handoffs/candidate-chooser-HANDOFF.md` — both merged
   branches' architecture, open questions and must-nots. Several inherited items originate there.
3. `gh issue view 16 --comments` (slice plan + acceptance rules), `gh issue view 1` **Notes** (hard rules:
   400 lines/file incl. tests; no secrets in source; no payloads in diagnostic logs; refer to issues by title),
   `CONTEXT.md`, `docs/quality-gate.md`, `docs/signing.md`, `Makefile`.
4. Sources you will touch: `Sources/JevPasteApp/**` (shell, indicator, chooser), `Sources/SmartPasteCore/`
   (read; changes need `ask`), `Sources/JevGateway/*`, `scripts/` + `.git/hooks` wiring for the pre-commit hook,
   `Tests/JevPasteAppTests/*`.
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. `make check` green before every commit.
- ≤ 400 lines per file, split by concern. Descriptive names from the glossary. No new dependencies without `ask`.
- Core (`Sources/SmartPasteCore`) changes need `ask` first, with the seam reasoning.
- Commit small on `harden`; push after each gate. Do not merge.
- `~/Applications/JevPaste.app` is shared: `make install` **only** when a gate reply says go.

## Scope
From the ticket body:
1. **Launch-time grant self-check**: on launch, if `AXIsProcessTrusted()` is false (including the stale-grant
   case where Settings shows ON), show a **visible** indicator notice with a short actionable message; log it.
   Re-check on a reasonable occasion (e.g. next ⌘⇧V) rather than polling forever — propose the exact rule at
   GATE A. No silent degradation.
2. **Launch-at-login**: `SMAppService.mainApp` registration, toggleable from the status-item menu, state
   persisted/reflected correctly. Propose the menu wording at GATE A.
3. **Pre-commit hook checks the staged snapshot**, not the working tree (today a dirty tree can pass/fail the
   wrong content). Keep it simple; document the mechanism in `docs/quality-gate.md`.
4. **Document signing-identity rotation** in `docs/signing.md`: what a `jevpaste-dev` cert rotation requires
   (re-sign, TCC migration event, exact steps + verification).

From the inherited list (ticket's newest comment):
5. Hotkey registration failure → visible indicator notice (today silent).
6. Indicator says "click to cancel" during the uninterruptible ≤ 150 ms delivery → change the wording/state
   during delivery so it doesn't promise a cancel that can't happen.
7. Jev pre-warm and/or cancel token — **decide at GATE A**: propose whether a URLSession pre-warm on launch
   and cancelling the in-flight request on cancel are worth it; implement only what the supervisor approves.
8. Fully-qualified enum in the outcome log line (small log cleanup).
9. `TargetAppFocusReturn` weak-self poll: torn down mid-poll → reply never sent. Unreachable in prod today —
   make it structurally safe or document why not, your call at GATE A.
10. `ChooserContent` line counting for lone `\r` — add the missing test (fix only if it fails).
11. "History read failed" notice is unreachable until the history UI exists — verify and leave a code comment
    pointing at [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27); no dead-code
    removal that the history UI will need.

Out of scope: the history UI, pre-check rules, anything touching Candidate derivation or Jev semantics.

## Live runs (all gated — `ask` and wait for go)
- L1. `make install` + launch: grant self-check shows nothing when granted; log line proves the check ran.
- L2. Launch-at-login toggle: enable, verify `SMAppService` status; Daniel confirms menu state after relaunch.
- L3. **Live regression check of the indicator's click-to-cancel** after the panel-parts extraction (inherited
  item; chooser handoff §5 item 6): a Paste Attempt whose indicator is clicked during processing → "Cancelled".
- Serialize with the supervisor's own live runs; batch your asks so Daniel's involvement is minimal.

### Tests
- Shell tests over the existing fake surfaces/clock for: grant-check notice mapping, hotkey-failure notice,
  delivery-phase indicator wording, `ChooserContent` `\r` counting.
- Hook change: prove staged-vs-worktree behaviour with a scripted git scenario (can be a small shell test run
  manually and documented, if wiring it into `make check` is disproportionate — say which at GATE B).

## Steps
1. `docs/design/hardening.md` (≤ 90 lines): each scope item → chosen mechanism, visible form, what is
   unit-tested vs live-proven, the GATE A decisions (items 1, 2, 7, 9) each restated in one line, and the
   live-run plan. **GATE A**: ask with the path and those one-liners.
2. Implement TDD, small commits.
3. Live runs L1–L3 (gated).

## Final steps
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your
  files, and the proof evidence.
- Write `docs/handoffs/harden-HANDOFF.md` on your branch (commits, architecture + why, review findings once
  known, merge touchpoints, open questions/live gaps with exact steps, must-nots, suggested skills). Commit it.
- Post a report comment on issue #28: what was built, test count, proof evidence, deviations, open questions.
  **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`[harden] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
