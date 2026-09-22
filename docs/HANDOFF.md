# Handoff — jevpaste (Wayfinder map in execution phase)

Repo: `/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main` @ 2ff715d, clean,
pushed). Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking (`gh` authenticated; wiring
via GraphQL `addSubIssue` / `addBlockedBy` with header `GraphQL-Features: sub_issues,issue_dependencies`).

## Where things stand

Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1).
**Read its body first** (Destination, Notes = hard rules incl. models and the review chain, Decisions-so-far
index, fog, out-of-scope). Glossary: `CONTEXT.md`. Design docs: `docs/design/*.md`. Worker briefs (use as
templates): `docs/briefs/*-brief.md` — `tracer-bullet-brief.md` and `sqlite-history-brief.md` are the newest.

This session executed **wave 2**, both merged with resolution comments, report comments and two-pass reviews:

- [Tracer bullet: first end-to-end smart paste](https://github.com/DanielMulec/jevpaste/issues/24#issuecomment-5783953394)
  — the installed app performs a real Smart Paste. Daniel's live run: Chrome `data:` textarea labelled
  "Email address", the email line chosen from a three-line synthetic signature, 1.3 s cold / ≈0.5 s warm, ✓ shown,
  clipboard restored, visible "No text field focused" on the Finder desktop. Shell = `SmartPasteApplication`
  composition root, `RunLoopPasteAttemptClock`, `IndicatorPresenter`/`IndicatorPanel`/`OutcomeMessage`, and three
  **interim stubs in `Sources/JevPasteApp/Interim/`** that later slices replace: `SecureTargetAndConcealedItemPreCheck`,
  `DiscardingHistoryRepository`, `UnbuiltCandidateChooser` (+ `IndicatorPresenter.explainNextCancellationAsChooserNotBuilt()`).
- [Implement the SQLite history repository](https://github.com/DanielMulec/jevpaste/issues/23#issuecomment-5783906606)
  — `HistoryRepository` seam widened (`items()` newest first, `delete`, `clearAll`, `changeRetentionLimit`;
  identity = trimmed text, byte-exact, no ids). `SQLiteHistoryRepository(fileURL:retentionLimit:onFailure:)`
  throws on an unusable file; `onFailure` runs **on the repository's serial queue** — never call `items()` from it.

225 tests in 42 suites, `make check` green.

**Frontier (open, unblocked, unclaimed):**
- [Add clipboard capture and persistent history](https://github.com/DanielMulec/jevpaste/issues/25) — **next**.
  Brief must cover: replace `DiscardingHistoryRepository` with `SQLiteHistoryRepository` (init failure → visible
  indicator + log, app still runs without history); route `onFailure` to the indicator via the main actor; seed the
  Active Item from the clipboard present at launch (open question from #24 — needs a small `CopyCapture`/`Clipboard`
  addition in Core, decide at GATE A); own writes stay invisible (already in Core); proof = copy, quit, relaunch,
  `items()` shows it. Do not build the history UI.
- [Implement the Candidate Chooser UI](https://github.com/DanielMulec/jevpaste/issues/26) ∥
  [Harden installation and daily use](https://github.com/DanielMulec/jevpaste/issues/28) — both unblocked now.
  Hardening inherits: hotkey registration failure is silent (#22 report), "click to cancel" shown during the
  uninterruptible 120 ms delivery (#24 review, declined as a shell fix — no port signal), no Jev pre-warm, no Jev
  cancel token, outcome log prints the fully-qualified enum (cosmetic).
- Prototypes with Daniel: [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14)
  (blocks [Implement Pre-check rules](https://github.com/DanielMulec/jevpaste/issues/20); can use `JevPasteApp --probe`),
  [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9)
  (blocks [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27)).
- Then [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29) (blocked by 26, 27, 28).

## Models and the review chain (see map Notes; unchanged)
- Workers: `anthropic/claude-opus-5-5:medium` in **separate Pi instances in Herdr panes** (never subagents).
- Reviewer: **one** fresh `openai-codex/gpt-6-sol:medium`, own pane, detached worktree at the branch head,
  `REVIEW-BRIEF.md` written into that worktree (VERDICT / BLOCKING / NON-BLOCKING / DUPLICATION / GAPS / METHOD).
  For the delta re-review append a "Delta re-review" section to the same brief; if the first reviewer agent is
  still listed by `herdr agent list`, prompt it again, else start a fresh one. GPT-6-Sol was excellent again
  (found the early-429 cancel gap and the invisible SQLite failures; ran `make check` itself). This session
  declined only "relabel during delivery".
- Supervisor reads the core files at Gate B before approving; then report comment (Gate C); author idles during review.

## Running workers — exact protocol
1. Write the brief into `docs/briefs/`, commit to `main`, then `git worktree add -b <branch> ~/.pi/worktrees/jevpaste/<branch> main`.
2. `herdr pane split --current --direction right --cwd <worktree> --no-focus` — the JSON key for the id varies;
   read it back with `herdr pane list` (match on cwd). **Sleep 4 s** before
   `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model <model>`.
3. First prompt: `First run in bash: env | grep '^PI_MODEL'. Then read docs/briefs/<x>.md … supervisor intercom id <ID>.`
4. Give workers **this session's intercom id** (`intercom status`); ids `01a0cac3` (this session), `01a0ca65`, `01a0c5fd` are dead.
5. Answer a pending `intercom ask` only with `intercom reply` (replyTo = its id); a `herdr agent prompt` queues behind it.
6. Gates: A design doc → B `make check` + `wc -l` + proof → C report comment → review → fixes → delta review → merge.
7. **Merge discipline (learned this session):** `git merge --no-ff origin/<branch>` on `main`, then `make check`
   **before** `git push`. Two branches that each passed alone conflicted semantically (the tracer's history stub
   did not conform to the seam the SQLite branch widened); `main` was red on origin for a minute.
8. Resolution comment, close, map gist (link the *resolution* comment id), `herdr pane close <id>`,
   `git worktree remove --force`, delete the branch.

## Environment facts
- Installed `~/Applications/JevPaste.app` = tracer bullet at 5c542db (pre-review-fix build), **not running**.
  `make install` before the next live run; the `jevpaste-dev` identity keeps the Accessibility grant.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live: ~1.2–1.3 s cold, ~0.3–0.5 s warm.
- History file will be `~/Library/Application Support/jevpaste/history.sqlite` (not created yet by the app).
- Pre-commit hook runs `make check` (~1 min); still run `npm ci` + one plain `swift build` per fresh worktree.
- Worktrees left: research/spike only (`jev`, `macos`, `macos-probe`, `quality`, `signing`, `spike-contract`).
  Panes: only this supervisor's `wC:p1` (and an unrelated `wB:p1`).

## Working with Daniel
- Short numbered questions with a recommended answer; he answers from his phone. Don't answer for him.
- Blanket approval for Keychain/Accessibility/toolchain; synthetic payloads only in real apps; he performs
  ⌘⇧V for live runs when asked (`done`/`nothing`/`failed`) and likes to press several times to watch the panel.
- Wayfinder governs; refer to tickets by linked title. One non-research ticket per supervisor session —
  supervising execution tickets via workers is fine (this session supervised two).

## Suggested skills
- `wayfinder` (every session), `pi-intercom` + `herdr --skill` (workers), `codebase-design` (capture+history
  touches Core's `CopyCapture`), `tdd` (briefs), `prototype` (tickets 14 and 9), `grilling` + `domain-modeling`
  only if a new decision surfaces (e.g. how to seed the pre-launch clipboard).
