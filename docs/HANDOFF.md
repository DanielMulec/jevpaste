# Handoff — jevpaste (Wayfinder map in execution phase)

Repo: `/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main` @ 0ef117e + this
handoff commit, clean, pushed). Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking
(`gh` authenticated; wiring via GraphQL `addSubIssue` / `addBlockedBy` with header
`GraphQL-Features: sub_issues,issue_dependencies`).

## Where things stand — PAUSED MID-WAVE 3 (Daniel left for work)

Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1).
**Read its body first** (Destination, Notes = hard rules incl. models and the review chain, Decisions-so-far
index, fog, out-of-scope). Glossary: `CONTEXT.md`. Design docs: `docs/design/*.md`. Worker briefs (use as
templates): `docs/briefs/*-brief.md` — `capture-history-brief.md` and `candidate-chooser-brief.md` are the newest
and include the "Shared files" section pattern for parallel workers.

This session ran **wave 3** as two parallel workers (both claimed = assigned to Daniel, both **open, not merged**):

| ticket | branch @ head | state |
|---|---|---|
| [Add clipboard capture and persistent history](https://github.com/DanielMulec/jevpaste/issues/25) | `capture-history` @ 0071eaa | Gate B + C passed; [report](https://github.com/DanielMulec/jevpaste/issues/25#issuecomment-5789267575); **GPT-6-Sol review running** in pane `wC:p0`, worktree `~/.pi/worktrees/jevpaste/review-capture`, findings appended to its `REVIEW-BRIEF.md` |
| [Implement the Candidate Chooser UI](https://github.com/DanielMulec/jevpaste/issues/26) | `candidate-chooser` @ f9eff60 | live step A passed (chooser shown, ↓+Enter chose 2nd email, ✓, ⌘V restored); Gate B + C passed; [report](https://github.com/DanielMulec/jevpaste/issues/26#issuecomment-5789291286); **GPT-6-Sol review running** in pane `wC:p11`, worktree `~/.pi/worktrees/jevpaste/review-chooser`, findings appended to its `REVIEW-BRIEF.md` |

Both live runs were done by Daniel; both worker Pi instances are still alive in Herdr panes `wC:pY` (capture) and
`wC:pZ` (chooser) unless the machine was restarted. Live proof gaps to close next session with Daniel:
- chooser: **Esc cancellation and click-away cancellation not proven live** (only choose was);
- capture: the textarea's exact text after the seeded paste was not read back (log says `outcome inserted`);
- seeding decision (pre-launch clipboard → Active Item + recorded) is **provisional** — recommended and
  implemented; Daniel never answered. Opting out = pass `nil` for `contentsAtLaunch` in `SmartPasteApplication`.

225 → 246 (capture) / 244 (chooser) tests; `make check` green on each branch alone. **They have not been merged
together yet** — expect a semantic merge to resolve (see "Merge plan").

## Resume checklist (do in order)
1. `intercom status` → your id. `herdr agent list` / `herdr pane list` → which of `capture-worker` (`wC:pY`),
   `chooser-worker` (`wC:pZ`), `review-capture` (`wC:p0`), `review-chooser` (`wC:p11`) still exist.
2. Read both `~/.pi/worktrees/jevpaste/review-{capture,chooser}/REVIEW-BRIEF.md` — the review is appended below
   the brief (VERDICT …). For each: BLOCKING items → prompt the worker (`herdr agent prompt <name> "…"` or intercom
   to its session; give it your new intercom id) to fix on its branch, push, then a "Delta re-review" section by
   the same reviewer (prompt it again if still listed, else a fresh one); then merge. If a worker is gone, start a
   fresh Opus instance in its worktree with a short fix brief.
3. Supervisor judgement on review findings: accept real bugs/duplication; decline scope creep with a one-line
   reason in the report thread (previous sessions declined e.g. "relabel during delivery").
   Note for the chooser review: `hideWhileChoosing()` calls the surface's `hide()`, which after the capture merge
   goes through `HistoryNoticeSurface` — a waiting history notice would then show under the chooser. Decide at
   merge time (simplest: acceptable; or defer notices while the chooser is open).
4. **Merge plan:** merge `capture-history` first (`git merge --no-ff origin/capture-history`, `make check`, push),
   then `candidate-chooser` — expect conflicts in `SmartPasteApplication.swift` (capture changed the presenter
   `surface:` + `capture` lines; chooser changed the `chooser:` line and removed the interim chooser) and possibly
   `docs/design/app-shell.md`. `make check` **before** push. Both branches were told not to touch each other's files.
5. Resolution comment + close + map gist for each (link the report comment ids), then `herdr pane close`,
   `git worktree remove --force`, delete branches. Also remove the review worktrees.
6. Next frontier after both merge: [Harden installation and daily use](https://github.com/DanielMulec/jevpaste/issues/28)
   (unblocked, unclaimed; inherits: silent hotkey-registration failure, "click to cancel" during the uninterruptible
   120 ms delivery, no Jev pre-warm, no Jev cancel token, fully-qualified enum in the outcome log, and now the
   history-read notice unreachable until the history UI). Prototypes with Daniel:
   [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14)
   and [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9)
   (blocks [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27)). Then
   [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29).

## Models and the review chain (see map Notes; unchanged)
- Workers: `anthropic/claude-opus-5-5:medium` in **separate Pi instances in Herdr panes** (never subagents).
- Reviewer: **one** fresh `openai-codex/gpt-6-sol:medium`, own pane, detached worktree at the branch head,
  `REVIEW-BRIEF.md` written into that worktree (VERDICT / BLOCKING / NON-BLOCKING / DUPLICATION / GAPS / METHOD).
  For the delta re-review append a "Delta re-review" section to the same brief; if the first reviewer agent is
  still listed by `herdr agent list`, prompt it again, else start a fresh one.
- Supervisor reads the core files at Gate B before approving; then report comment (Gate C); author idles during review.

## Running workers — exact protocol
1. Write the brief into `docs/briefs/`, commit to `main`, then `git worktree add -b <branch> ~/.pi/worktrees/jevpaste/<branch> main`.
2. `herdr pane split --current --direction right|down --cwd <worktree> --no-focus`; read the pane id back with
   `herdr pane list` (match on cwd). **Sleep 4 s** before
   `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model <model>`; sleep ~6 s, then
   `herdr agent prompt <name> "First run in bash: env | grep '^PI_MODEL'. Then read docs/briefs/<x>.md … supervisor intercom id <ID>."`
3. Give workers **this session's intercom id** (`intercom status`); ids `01a0cc6f` (this session), `01a0cac3`,
   `01a0ca65`, `01a0c5fd` are dead.
4. Answer a pending `intercom ask` only with `intercom reply` (replyTo = its id); a `herdr agent prompt` queues behind it.
5. Gates: A design doc → B `make check` + `wc -l` + proof → C report comment → review → fixes → delta review → merge.
6. **Parallel workers:** give each a "Shared files" section naming exactly which lines/files the other touches;
   serialize live runs (the installed app is shared) — hold both at step 3 and release one at a time.
7. **Merge discipline:** `git merge --no-ff origin/<branch>` on `main`, then `make check` **before** `git push`.
8. Resolution comment, close, map gist (link the *report* comment id), `herdr pane close <id>`,
   `git worktree remove --force`, delete the branch.

## Environment facts
- Installed `~/Applications/JevPaste.app` = **candidate-chooser 32a4756** (chooser build; has the interim discarding
  history, not SQLite). Should be quit; verify with `pgrep -f JevPaste.app`. `make install` before the next live run.
- History file exists now: `~/Library/Application Support/jevpaste/history.sqlite` (0600), holds synthetic rows
  `JEVPASTE-HISTORY-*`, the Tamsin seed, and one row of Daniel's real pre-launch clipboard — never print it.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live: ~1.2–1.7 s cold, ~0.3–0.5 s warm.
- Pre-commit hook runs `make check` (~1 min); run `npm ci` + one plain `swift build` per fresh worktree.
- Worktrees: `capture-history`, `candidate-chooser`, `review-capture` (+ research/spike ones: `jev`, `macos`,
  `macos-probe`, `quality`, `signing`, `spike-contract`). Temp files `/tmp/jevpaste-live.txt`, `/tmp/jevpaste-chooser.txt`.
- `/tmp` synthetic text files + `open -e` is the way to give Daniel text to copy — **never** "copy from any text
  editor" (⌘C and mouse selection interfere in Herdr; he copies by mouse-marking there).

## Working with Daniel
- Short numbered questions with a recommended answer; he answers from his phone. Don't answer for him.
- Blanket approval for Keychain/Accessibility/toolchain; synthetic payloads only in real apps; he performs
  ⌘⇧V for live runs when asked (`done`/`nothing`/`failed`). Have workers open Chrome `data:` tabs for him.
- Wayfinder governs; refer to tickets by linked title. Supervising several execution tickets via workers in one
  session is fine (this session: two, in parallel).

## Suggested skills
- `wayfinder` (every session), `pi-intercom` + `herdr --skill` (workers), `codebase-design` (hardening touches
  the shell broadly), `tdd` (briefs), `prototype` (tickets 14 and 9).
