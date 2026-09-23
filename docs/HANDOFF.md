# Handoff — jevpaste supervisor (Wayfinder map in execution phase)

Written for a fresh supervisor session that has never seen the previous one. Repo:
`/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main` clean and pushed).
Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking (`gh` authenticated; wiring via
GraphQL `addSubIssue` / `addBlockedBy` with header `GraphQL-Features: sub_issues,issue_dependencies`).

## Context (read, don't re-derive)
- Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1) —
  **read its body first**: Destination, Notes (hard rules, models, review chain), Decisions-so-far, fog, out of scope.
- Glossary `CONTEXT.md` (now includes **Launch Adoption** — never say "seeding"; a synthetic test row is a *fixture*);
  design docs `docs/design/*.md`; quality gate `docs/quality-gate.md`; signing `docs/signing.md`.
- Worker briefs (templates for new ones): `docs/briefs/*-brief.md` — newest `capture-history-brief.md` and
  `candidate-chooser-brief.md` show the "Shared files" section used for parallel workers.
- **Per-branch worker handoffs are retired** (Daniel, 2026-09-23): workers fold commits/architecture/merge
  touchpoints/open questions into their ticket report comment instead. `docs/handoffs/*` holds only the two
  historical wave-3 files; their still-live facts were absorbed into this file's "Durable notes".

## Where things stand (updated 2026-09-23 evening)
- [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14)
  **resolved and closed**: no per-Target refusal/warning needed (nothing sends or executes pasted newlines).
  Prototype asset: unmerged branch `multiline-probe` (keep). Side finding → new frontier-adjacent ticket
  [Restore Smart Paste in the ChatGPT desktop app](https://github.com/DanielMulec/jevpaste/issues/33)
  (`com.openai.codex` = Daniel's ChatGPT app; resolver gets kAXErrorNoValue; blocks the acceptance suite).
  [Implement Pre-check rules](https://github.com/DanielMulec/jevpaste/issues/20) is now unblocked.
- [Harden installation and daily use](https://github.com/DanielMulec/jevpaste/issues/28): branch `harden`
  (ef9092d) implemented, 294 tests, live-proven with Daniel (grant check, click-to-cancel regression,
  Open-at-Login left ON). Pending: report comment → GPT-6-Sol review → merge. Shared pre-commit hook now checks
  the **staged snapshot** (`scripts/check-staged-snapshot.sh`; fresh ~56 s, incremental ~10 s+compile).
- Installed `~/Applications/JevPaste.app` = harden ef9092d (running); pre-harden state was main cc556cc.

## Durable notes (rescued from retired worker handoffs + today's runs)
- `sqlite3`'s `trim()` strips spaces only — compare history rows with `LIKE`, not `trim()`, for multi-line text.
- Chooser behaviours intentionally not test-asserted: close-triggered resign-key firing synchronously,
  Enter+click in one turn, close-before-reply ordering (see `PanelCandidateChooser` reply-once design).
- Herdr automation: `herdr tab focus` from the CLI can silently no-op — gate every synthetic keystroke/trigger on
  a verified `herdr pane get <id>` focused=true + frontmost-app check, and abort otherwise (a misdelivery landed
  in the supervisor pane before this gate existed). Prefer new **tabs** (`herdr tab new`) over splits for scratch
  panes and extra workers (Daniel's preference).
- Worker shells have no Accessibility; only the signed bundle can post events. For probe automation, add a signal
  trigger (e.g. SIGUSR1 → same delivery path) to the signed app rather than trying osascript.
- Reviewer prompts must end with an `intercom send <supervisor-id>` step — a reviewer told only to "write the
  verdict and stop" finishes silently and the supervisor waits forever (happened 2026-09-23; Daniel had to relay).

**Wave 3 is complete.** `main` @ f610b8b: `capture-history` (b6517b5) and `candidate-chooser` (f610b8b) merged,
`make check` = 271 tests / 50 suites. Both tickets closed with resolution + live-proof comments; map gists added.
No worker is running; no worktrees for finished branches remain (only research/spike ones).

Decisions this session (Daniel):
- **Launch Adoption confirmed**: the clipboard at launch is adopted like a live copy (Active Item + recorded).
- Merge-time: a waiting history notice may show while the chooser is open — informational, accepted
  (`docs/design/app-shell.md`).
- Toolchain workaround on the merge: explicit `@MainActor` on `FirstClickView` (`StatusItemPanelParts.swift`) —
  the merged module otherwise mangled `onClick` inconsistently and failed to link. Commented in code; do not remove.

Live-proven on f610b8b with Daniel: chooser Esc, click-away, title "Which one for Email address?"; Launch Adoption
paste inserts the pre-launch email.

## Open tickets (all children of the map)
| ticket | type | state |
|---|---|---|
| [Harden installation and daily use](https://github.com/DanielMulec/jevpaste/issues/28) | task | **frontier**, unclaimed; inherited list consolidated in its newest comment |
| [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14) | prototype (HITL) | frontier; blocks Pre-check rules |
| [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9) | prototype (HITL) | frontier; blocks history UI |
| [Implement Pre-check rules](https://github.com/DanielMulec/jevpaste/issues/20) | task | blocked by 14 |
| [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27) | task | blocked by 9 |
| [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29) | task | after the above |
| [Extract typed tokens embedded in lines as Candidates](https://github.com/DanielMulec/jevpaste/issues/31) | grilling | blocked by 29 (surfaced live: `prefix + email` lines → No Suitable Match) |
| [Skip Jev when the Active Item yields a single Candidate](https://github.com/DanielMulec/jevpaste/issues/32) | grilling | blocked by 29 (trade-off: loses Jev's `none_of_these` gate) |

## Next session — in order
1. Read the map body and this file. `intercom status` → your id (all earlier ids are dead). No panes/agents exist;
   start fresh ones.
2. Pick one: Harden (worker, brief from the ticket body + its inherited-list comment; must read both
   `docs/handoffs/*-HANDOFF.md`) **or** one of the two prototypes with Daniel (`prototype` skill, live in the
   installed app). Harden can run as a worker while a prototype runs with Daniel — live runs stay serialized.
3. Worker protocol below; merge discipline; resolution comment + close + map gist.

## Models and the review chain (map Notes; unchanged)
- Workers: `anthropic/claude-opus-5-5:medium` as **separate Pi instances in Herdr panes** (never subagents).
- Reviewer: **one** fresh `openai-codex/gpt-6-sol:medium` per branch, own pane, detached worktree at the branch
  head, `REVIEW-BRIEF.md` written into that worktree (VERDICT / BLOCKING / NON-BLOCKING / DUPLICATION / GAPS /
  METHOD). Delta re-review = a "Delta re-review request" section appended to the same file; expect to start a fresh
  reviewer instance for the delta. GPT-6-Sol has found one real blocking bug per branch so far.
- Supervisor reads the core files at Gate B before approving; report comment (Gate C); author idles during review;
  after the review the supervisor posts a review-chain summary on the ticket. Merge-only changes with no behaviour
  change need no pass; anything that is a *workaround* gets a code comment and a ticket note.

## Running workers — exact protocol
1. Write the brief into `docs/briefs/`, commit to `main`, `git worktree add -b <branch> ~/.pi/worktrees/jevpaste/<branch> main`.
2. `herdr pane split --current --direction right|down --cwd <worktree> --no-focus`; read the pane id back with
   `herdr pane list` (match on cwd). Sleep 4 s, then `herdr agent start <name> --kind pi --pane <id> --timeout 60000
   -- --model <model>`; sleep ~6 s, then `herdr agent prompt <name> "First run in bash: env | grep '^PI_MODEL'.
   Then read docs/briefs/<x>.md … supervisor intercom id <ID>."`
3. Answer a pending `intercom ask` only with `intercom reply` (replyTo = its id); a `herdr agent prompt` queues behind it.
4. Gates: A design doc → B `make check` + `wc -l` + proof → C report → review → fixes → delta review → merge.
5. Parallel workers: a "Shared files" section per brief; live runs are serialized (the installed app is shared).
6. Every worker writes `docs/handoffs/<branch>-HANDOFF.md` on its branch before it ends (commits, architecture +
   why, review findings and resolutions, merge touchpoints, open questions/live gaps with exact steps, must-nots,
   suggested skills). Require it in the brief's final steps.
7. Merge discipline: `git merge --no-ff origin/<branch>` on `main`, `make check` **before** `git push`. If the
   link fails with an undefined-symbol mangling mismatch after adding files, `swift package clean` first; the
   `FirstClickView` case is documented above.
8. Resolution comment, close, map gist (link the report comment id), pane close, worktree remove, branch delete.

## Environment facts
- Installed `~/Applications/JevPaste.app` = **merged main f610b8b**, currently running. The `jevpaste-dev`
  identity keeps the Accessibility grant.
- `~/Library/Application Support/jevpaste/history.sqlite` (0600) holds synthetic rows, fixtures and rows of
  Daniel's real clipboard — never print it; read only `JEVPASTE-…` rows.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live ~1.1–1.7 s cold, ~0.2–0.5 s warm.
- Pre-commit hook runs `make check` (~1 min); `npm ci` + one plain `swift build` per fresh worktree.
- Worktrees present: research spikes only (`jev`, `macos`, `macos-probe`, `quality`, `signing`, `spike-contract`).
- `/tmp/jevpaste-chooser.txt` (name + two emails) and `/tmp/jevpaste-chooser-test.html` (Chrome "Email address"
  textarea) are the current live-run fixtures. **Payload rule:** candidates are whole lines — a line like
  `PREFIX email@x` is *not* an email candidate; use pure values per line.

## Working with Daniel
- Short numbered questions with a recommended answer; he answers from his phone. Don't answer for him.
- Blanket approval for Keychain/Accessibility/toolchain; synthetic payloads only in real apps; he performs ⌘⇧V for
  live runs when asked (`done`/`nothing`/`failed`). Open Chrome pages and TextEdit files (`/tmp/…` + `open -e`) for
  him — **never** "copy from any text editor"; ⌘C and mouse selection interfere in Herdr.
- He cares about naming: no ambiguous terms (the "seeding" lesson). Explain *why* before recommending; he will
  challenge shortcuts ("redundant" ≠ "harmless").
- Wayfinder governs; refer to tickets by linked title.

## Suggested skills
- `wayfinder` (every session), `pi-intercom` + `herdr --skill` (workers), `codebase-design` (hardening touches the
  shell broadly), `tdd` (briefs), `prototype` (tickets 14 and 9), `grilling` + `domain-modeling` (tickets 31, 32).
