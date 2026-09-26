# Narrowing (#50) — worker handoff (worker 2 → worker 3), 2026-09-26

**This file replaces `~/.pi/worktrees/jevpaste/narrowing-handoff.md`** (worker 1 → 2, outside the repo). That old
file stays only for one thing: the supervisor's **Gate A reply, verbatim** (section "Gate A reply, verbatim"). Read
it there; don't copy it here.

Worktree `~/.pi/worktrees/jevpaste/narrowing`, branch `narrowing` (pushed). Supervisor intercom id
`01a0de5c-66a4-73bd-9ff8-6ee5f9f81836` (a new supervisor session may take over; use the id the supervisor gives you).

## Read first, in this order
1. `docs/briefs/narrowing-brief.md`: the brief and protocol (steps, gates, live-proof rules, payload rule).
2. `docs/design/narrowing.md`: the design as built (Gate A approved; `1c06af2` added one rule, see below).
3. `docs/acceptance/run-2026-09-26-narrowing.log`: live proof so far, parts 1–3, with results and findings.
4. `git log --oneline 9e2a6d4..` for what was built; commit messages are the summary.

## State
- Gates: **A approved**, **B approved** (supervisor ran `make check` and `make planning-time`, read the Core and
  Gateway diff). Gate C: not yet.
- `make check` green at `1c06af2` (442 tests, ~3.5 s). `make planning-time` (release build, not part of `check`)
  holds 20 ms/100 ms/250 ms ceilings. Numbers are in the d81c604 commit message and Gate B.
- **Installed app = `568c96d`** (before `1c06af2`), running normally (no trigger flag). Daniel uses it daily.
- Clipboard vault restored after every run. No test tabs, no TextEdit docs, no Herdr scratch tab left open.

## Since the old handoff (details: commits and the log)
- **Performance** (worker 1's open item 1): planning is linear. `DocumentOrder.swift` (rolling hash), children built
  once per step, fine runs counted only to the cap, ASCII size table, `containsExactly` for byte-exact checks. 3000
  lines: 83 s → 71 ms (release). `make planning-time` + `NarrowingPlanningTimeTests` are the committed evidence.
- Missing tests written (`NarrowingStepTests`, `PasteAttemptNarrowing(Clock)Tests`, App log-line/outcome tests); App
  tests restored and adapted; FreeTextTarget* tests renamed; replay grew 12 → 14 cells (Gate A said 14).
- Docs folded (`b117e47`), README privacy (`568c96d`).
- **(A) `1c06af2`, approved by Daniel:** no child may equal, byte for byte, what keeping its parent pastes (step 1:
  `OuterLineBreaks.stripped(copy)`). Found live: copies ending in a line break offered a duplicate of the keep
  option. Replay unchanged (no-op on all recorded cells). **Not installed yet.**
- **(B), Daniel: record only, for Gate C and the next Narrowing round:** a follow-up that fits none of its four
  forms is still sent (as in the spike, `r2.py` 583–590). Live: it drew a 400 in (c). No fix now unless (c) still
  fails after (A).
- **350-line finding, for Gate C open questions** (supervisor): by the size model, a 350-line list (the `logList`
  generator in `NarrowingPlanningTimeTests`) doesn't fit one call while 300 and 400 lines do (grouping isn't monotonic
  in length). Report what is actually sent for 350 and what happens then (Jev decides; no local refusal).
- **F1 finding (Daniel's step 1, log part 3):** Jev chose `ask_user`. The chooser listed 6 rows including two
  fragments of the second address but **not the full second address**. Daniel picked a fragment, and it was inserted
  byte-exact. The spike's criterion 4 checked only *that* `ask_user` was chosen, never *what* the chooser lists.

## What's left, in order
1. **F1 diagnosis** (diagnosing-bugs skill). Question (i): why did the full second-address line get no weight while
   two of its fragments did? Hypothesis: excerpt-id confusion in the ids form (weight landing on ids next to the
   line's id). Plan: rebuild the exact step-1 request offline (f1 copy = the log's fixture description; Target
   Context = the German form's E-Mail field; plan it with `StepPlanner`), send it live about 5× in the ids form and
   about 5× in the full-text form (synthetic data, a few cents; e.g. a `JEVPASTE_LIVE_JEV=1`-gated scratch test that
   prints per option id: text byte length, a short digest, p, never commit its text output). Compare where the
   weight lands.
2. **Report to the supervisor** with those numbers, and (ii) a proposed chooser list rule for Daniel (today: every
   option of the deciding choice with p > 0, most likely first). **No design change without Daniel.**
3. After Daniel decides: implement TDD if needed, `make check`, commit, push.
4. **Install** (ask the supervisor first, as always) → re-run (c) (the 300-line list with marker line and trailing
   newline, gift field) and the Kommentar case (a3) on the new build → Daniel's block again: step 1 (two addresses →
   chooser), steps 2+3 (WhatsApp and ChatGPT composer, three-line copy, whole copy, nothing sent). Append to the log.
5. Report comment on #50 per brief step 5 (incl. (B), the 350-line finding, the F1 finding, known misses) → **GATE C**
   `ask`, then end the turn. Don't merge, don't close the issue.

## Traps
- **Stage copies for Daniel**: he can't copy from the Herdr TUI. `pbcopy` the fixture, then verify JevPaste took it:
  it logs nothing for a copy, so compare a read-only SHA-256 of the newest `clipboard_item` row in
  `~/Library/Application Support/jevpaste/history.sqlite` (ordered by `copy_sequence`) with the fixture's digest.
  Print digests only.
- **Committed logs**: no fixture markers (`JEVPASTE-…`), no literal text, no titles, no `/Users/<name>`. Name
  fixtures by byte count and digest (a reviewer blocked a merge on this before).
- **Chrome MCP**: the first call after a while may raise Chrome's "Remote-Fehlerbehebung zulassen?" sheet and time
  out. Screencapture, ask; only Daniel clicks it; don't kill the MCP process. `evaluate_script`/`close_page` need
  `pageId`. Before `close_page`: re-list and check the URL is your own `data:` page.
- **Triggering**: installed app via `open ~/Applications/JevPaste.app --args --accept-signal-trigger`; SIGUSR1 to
  that one pid (a copy of `scripts/acceptance/press.sh` with `pgrep -f '… --accept-signal-trigger'`); gate on
  `lsappinfo front`, and for Chrome also on your tab being active. Vault save before, restore **before** the normal
  relaunch. Vault tool: `swiftc -O -o /tmp/jevpaste-acc/clipboard-vault scripts/acceptance/clipboard-vault.swift`.
- **Size model is approximate**: Jev's real limit is what counts (400 `max_tokens_exceeded` → "Too long for Smart
  Paste"). Never add a local size gate.
- Tooling: bare `swift test` doesn't link; use `make test` or the filtered command in the old handoff. `make format`
  before `make check`. `@Test(arguments:)` built from `static let` in a `@MainActor` suite needs `nonisolated`.
  Periphery strict flags test-only internal code. The pre-commit hook runs the full `make check` (~20 s).
- `NarrowingReplayTests` must stay byte-identical; any planner change runs it first.

## Suggested skills
- `~/.agents/skills/diagnosing-bugs/SKILL.md`: first, for the F1 diagnosis.
- `~/.agents/skills/tdd/SKILL.md`: for any fix Daniel approves.
- `~/.agents/skills/codebase-design/SKILL.md`: if the chooser rule needs a new home (it belongs in `NarrowingPolicy`).
- `~/.agents/skills/code-review/SKILL.md`: before Gate C.
