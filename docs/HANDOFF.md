# Handoff — jevpaste supervisor (Wayfinder map in execution phase)

Written for a fresh supervisor session that has never seen the previous one. Repo:
`/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main` clean and pushed).
Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking (`gh` authenticated; wiring via
GraphQL `addSubIssue` / `addBlockedBy` with header `GraphQL-Features: sub_issues,issue_dependencies`).

## Context (read, don't re-derive)
- Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1) —
  **read its body first**: Destination, Notes (hard rules, models, review chain), Decisions-so-far, fog, out of scope.
- Glossary `CONTEXT.md`; design docs `docs/design/*.md`; quality gate `docs/quality-gate.md`; signing `docs/signing.md`.
- Worker briefs (templates for new ones): `docs/briefs/*-brief.md` — newest are `capture-history-brief.md` and
  `candidate-chooser-brief.md`, which show the "Shared files" section used for parallel workers.
- **Worker handoffs** (one per branch, written by the Opus worker that built it, on its branch):
  - `docs/handoffs/capture-history-HANDOFF.md` (branch `capture-history`)
  - `docs/handoffs/candidate-chooser-HANDOFF.md` (branch `candidate-chooser`)
  Read them with `git show origin/<branch>:docs/handoffs/<branch>-HANDOFF.md` before merging. **Any new worker
  that continues a branch, resolves its merge, or proves its live-run gaps must read that branch's handoff first**
  — put that instruction in its brief's "Read first" list, item 1.

## Where things stand
Wave 3 ran as two parallel workers; both branches passed Gate A/B/C, a GPT-6-Sol review (verdict fix), a worker
fix, and a delta re-review (verdict merge). **Neither is merged.** Review-chain summaries are the newest comments
on each ticket; full review texts are only in the (uncommitted) `REVIEW-BRIEF.md` of the review worktrees, which
Daniel is closing — the ticket summaries are the durable record.

| ticket (claimed = assigned to Daniel) | branch @ head | tests | report |
|---|---|---|---|
| [Add clipboard capture and persistent history](https://github.com/DanielMulec/jevpaste/issues/25) | `capture-history` @ cab0c7e (code d49d87b + handoff) | 249 / 47 suites | [report](https://github.com/DanielMulec/jevpaste/issues/25#issuecomment-5789267575) |
| [Implement the Candidate Chooser UI](https://github.com/DanielMulec/jevpaste/issues/26) | `candidate-chooser` @ db11505 (code d10a878 + handoff) | 247 / 45 suites | [report](https://github.com/DanielMulec/jevpaste/issues/26#issuecomment-5789291286), [addendum](https://github.com/DanielMulec/jevpaste/issues/26#issuecomment-5789338604) |

Daniel performed both live runs. Gaps still to prove with him (details + exact steps in the worker handoffs):
- chooser: **Esc** and **click-away** cancellation not proven live; chooser title text unconfirmed;
- capture: textarea text after the seeded paste not read back (log says `outcome inserted`);
- **seeding decision provisional**: the clipboard present at launch becomes the Active Item and is recorded
  (recommended, implemented, Daniel never answered). Ask him once; opting out = pass `{ nil }` for
  `contentsAtLaunch` in `SmartPasteApplication`.

## Next session — in order
1. Read the map body, this file, both worker handoffs. `intercom status` → your id (previous ids `01a0cc6f`,
   `01a0cac3`, `01a0ca65`, `01a0c5fd` are dead). All previous panes/agents were closed by Daniel; start fresh ones.
2. Ask Daniel the seeding question (numbered, with the recommendation) — the answer only affects one line.
3. **Merge** `capture-history` first: `git merge --no-ff origin/capture-history`, `make check`, push. Then
   `candidate-chooser`: expect conflicts in `Sources/JevPasteApp/SmartPasteApplication.swift` (capture changed the
   presenter `surface:` + `capture`/history lines; chooser changed the `chooser:` line and the `statusItemFrame`
   closure) and possibly `docs/design/app-shell.md`. Merge-time decision (documented on the chooser ticket):
   `IndicatorPresenter.hideWhileChoosing()` → `surface.hide()` now passes through capture's `HistoryNoticeSurface`;
   with d49d87b a hide while the presenter shows nothing is ignored, otherwise a waiting history notice may appear
   under the open chooser — accept (informational) or hold notices while the chooser is open; record the choice.
   `make check` **before** push. If the conflict resolution changes behaviour, one short GPT-6-Sol pass on the merge
   commit; otherwise none. If you delegate the merge to a worker, its brief must require both worker handoffs.
4. Resolution comment (link the report comment id), close, map gist for each ticket; `git worktree remove --force`
   for `capture-history`, `candidate-chooser`, `review-capture`, `review-chooser`; delete the two branches.
5. Live-proof gaps (with Daniel at the keyboard): `make install` from merged `main`, then the chooser Esc /
   click-away steps and the seeded-paste text check as listed in the worker handoffs. Record on the tickets.
6. Frontier then: [Harden installation and daily use](https://github.com/DanielMulec/jevpaste/issues/28)
   (unblocked, unclaimed; inherits: silent hotkey-registration failure, "click to cancel" during the uninterruptible
   120 ms delivery, no Jev pre-warm/cancel token, fully-qualified enum in the outcome log, focus-return completion
   lost if `TargetAppFocusReturn` is torn down mid-poll, CRLF splitting in chooser display rows, "History read
   failed" unreachable until the history UI). Prototypes with Daniel:
   [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14)
   (blocks [Implement Pre-check rules](https://github.com/DanielMulec/jevpaste/issues/20)) and
   [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9)
   (blocks [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27)). Then
   [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29).

## Models and the review chain (map Notes; unchanged)
- Workers: `anthropic/claude-opus-5-5:medium` as **separate Pi instances in Herdr panes** (never subagents).
- Reviewer: **one** fresh `openai-codex/gpt-6-sol:medium` per branch, own pane, detached worktree at the branch
  head, `REVIEW-BRIEF.md` written into that worktree (VERDICT / BLOCKING / NON-BLOCKING / DUPLICATION / GAPS /
  METHOD). Delta re-review = a "Delta re-review request" section appended to the same file; the reviewer pane
  usually exits after reporting, so expect to start a fresh instance for the delta. GPT-6-Sol found one real
  blocking bug per branch this session (a seed/observer race; a stale chooser cancel).
- Supervisor reads the core files at Gate B before approving; report comment (Gate C); author idles during review;
  after the review the supervisor posts a review-chain summary on the ticket.

## Running workers — exact protocol
1. Write the brief into `docs/briefs/`, commit to `main`, `git worktree add -b <branch> ~/.pi/worktrees/jevpaste/<branch> main`.
2. `herdr pane split --current --direction right|down --cwd <worktree> --no-focus`; read the pane id back with
   `herdr pane list` (match on cwd). Sleep 4 s, then `herdr agent start <name> --kind pi --pane <id> --timeout 60000
   -- --model <model>`; sleep ~6 s, then `herdr agent prompt <name> "First run in bash: env | grep '^PI_MODEL'.
   Then read docs/briefs/<x>.md … supervisor intercom id <ID>."`
3. Answer a pending `intercom ask` only with `intercom reply` (replyTo = its id); a `herdr agent prompt` queues behind it.
4. Gates: A design doc → B `make check` + `wc -l` + proof → C report → review → fixes → delta review → merge.
5. Parallel workers: a "Shared files" section per brief naming what the other touches; live runs are serialized
   (the installed app is shared) — hold both at step 3, release one at a time.
6. Every worker writes `docs/handoffs/<branch>-HANDOFF.md` on its branch before it ends (this session's format:
   commits, architecture + why, review findings and resolutions, merge touchpoints, open questions/live gaps with
   exact steps, must-nots, suggested skills). Require it in the brief's final steps.
7. Merge discipline: `git merge --no-ff origin/<branch>` on `main`, `make check` **before** `git push`.
8. Resolution comment, close, map gist (link the report comment id), pane close, worktree remove, branch delete.

## Environment facts
- Installed `~/Applications/JevPaste.app` = candidate-chooser 32a4756 (pre-fix chooser build, interim history) —
  quit. `make install` from merged `main` before any live run; the `jevpaste-dev` identity keeps the Accessibility grant.
- `~/Library/Application Support/jevpaste/history.sqlite` exists (0600): synthetic `JEVPASTE-HISTORY-*` rows, the
  Tamsin seed, and one row of Daniel's real pre-launch clipboard — never print it.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live ~1.2–1.7 s cold, ~0.3–0.5 s warm.
- Pre-commit hook runs `make check` (~1 min); `npm ci` + one plain `swift build` per fresh worktree.
- Worktrees present: `capture-history`, `candidate-chooser`, `review-capture`, `review-chooser`, plus research
  spikes (`jev`, `macos`, `macos-probe`, `quality`, `signing`, `spike-contract`). `/tmp/jevpaste-live.txt`,
  `/tmp/jevpaste-chooser.txt` hold synthetic live-run text.

## Working with Daniel
- Short numbered questions with a recommended answer; he answers from his phone. Don't answer for him.
- Blanket approval for Keychain/Accessibility/toolchain; synthetic payloads only in real apps; he performs ⌘⇧V for
  live runs when asked (`done`/`nothing`/`failed`). Have workers open Chrome `data:` tabs and TextEdit files
  (`/tmp/…` + `open -e`) for him — **never** "copy from any text editor"; ⌘C and mouse selection interfere in Herdr.
- Wayfinder governs; refer to tickets by linked title. Supervising several execution tickets via workers in one
  session is fine (this session: two, in parallel).

## Suggested skills
- `wayfinder` (every session), `pi-intercom` + `herdr --skill` (workers), `resolving-merge-conflicts` (step 3),
  `codebase-design` (hardening touches the shell broadly), `tdd` (briefs), `prototype` (tickets 14 and 9),
  `grilling` + `domain-modeling` only if a new decision surfaces.
