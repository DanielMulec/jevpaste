# Handoff — jevpaste supervisor (Wayfinder map in execution phase, after wave 5)

Written for a fresh supervisor session that has never seen the previous one. Repo:
`/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main` clean and pushed).
Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking (`gh` authenticated; wiring via
GraphQL `addSubIssue` / `addBlockedBy` with header `GraphQL-Features: sub_issues,issue_dependencies`).

## Context (read, don't re-derive)
- Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1) —
  **read its body first**: Destination, Notes (hard rules, models, review chain), Decisions-so-far, fog, out of scope.
- Glossary `CONTEXT.md`; design docs `docs/design/*.md` (now incl. `hardening.md`); quality gate
  `docs/quality-gate.md` (staged-snapshot hook); signing `docs/signing.md` (incl. rotation).
- Worker briefs (templates for new ones): `docs/briefs/*-brief.md` — newest `chatgpt-resolver-brief.md`
  (root-cause hunt), `pre-checks-brief.md` (Core task), `history-probe-brief.md` (UI prototype with live relay).
- **Per-branch worker handoffs are retired** (Daniel): workers fold commits/architecture/merge touchpoints/open
  questions into their ticket **report comment**. `docs/handoffs/*` holds only two historical wave-3 files;
  their still-live facts are in "Durable notes" below.

## Where things stand (end of 2026-09-23, second session — wave 5)
`main` @ 63079ad: `pre-checks` merged (320 tests / 61 suites). Resolved and closed this session:
- [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9) —
  Daniel delegated the design ("make it look like something Apple would be proud shipping"); recommendation =
  Spotlight-style panel under the status item (search, ↑/↓/Enter, pinned Active row, hover-✕/⌫ delete, confirmed
  clear-all), Core needs `CopyCapture.select(_:)` + an Active-Item observation port. Asset: unmerged branch
  `history-probe` (keep). Only Variant A ran live; B/C and checks 8–11 deferred to #27's acceptance.
- [Implement Pre-check rules](https://github.com/DanielMulec/jevpaste/issues/20) — merged: `LocalPreChecks`,
  nine regex-free secret rules, Target Context screening + outcome note (`showOutcome(_:note:)`). Two clean
  GPT-6-Sol passes. **Live proof still pending** (two presses; block in the ticket report § "Live proof pending").

**In flight — review-clean, NOT merged:** [Restore Smart Paste in the ChatGPT desktop app](https://github.com/DanielMulec/jevpaste/issues/33),
branch `chatgpt-resolver` @ 2f9e4fe, worktree `~/.pi/worktrees/jevpaste/chatgpt-resolver`, worker pane
`wC:p18` (tab `chatgpt-resolver`, agent `chatgpt`, idle; may be dead by next session — start fresh if so).
Root cause: Electron apps keep the AX tree asleep until `AXEnhancedUserInterface=true` is set on the application
element (walks never wake it; set returns kAXErrorNotImplemented yet takes effect ~1–3 s later; sticks per process).
Fix (Daniel's decision, option 2): on unreadable focus, set the flag, refuse with the typed
`PreCheckRefusal.targetWaking(applicationName:)` → "Waking ChatGPT for Smart Paste — press ⌘⇧V again in a
moment"; ⌘⇧V is the retry; 5 s per-pid wake window; no bundle ids; never reset. GPT-6-Sol: "merge after fixes +
live proof"; fixes done, delta approved. **Blocking = the live proof**, esp. the Finder control (native app with
nothing focused must NOT say "Waking Finder"; log category `TargetResolver` shows `focus unreadable` / `wake
requested … readBack=`). Instruction block: #33 report § "Live proof pending" (6 steps).

## Open tickets (all children of the map)
| ticket | type | state |
|---|---|---|
| [Restore Smart Paste in the ChatGPT desktop app](https://github.com/DanielMulec/jevpaste/issues/33) | task | claimed, code done, **needs live proof → merge**; blocks #29 |
| [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27) | task | **frontier** (unblocked by #9); build on the #9 resolution |
| [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29) | task | blocked by 27, 33; must include the #20 live proof |
| [Extract typed tokens embedded in lines as Candidates](https://github.com/DanielMulec/jevpaste/issues/31) | grilling | blocked by 29; new evidence: Jev is borderline on `label value@email` lines (#9 report) |
| [Skip Jev when the Active Item yields a single Candidate](https://github.com/DanielMulec/jevpaste/issues/32) | grilling | blocked by 29 |

## Next session — in order
1. Read the map body and this file. `intercom status` → your id (all earlier ids are dead).
2. **First live block with Daniel (~8 presses):** (a) #33 — `make install` from the `chatgpt-resolver` worktree,
   run the 6-step block, read the `TargetResolver` log; if Finder says "Waking", the worker fixes + delta review;
   else merge (`--no-ff`, `make check`, push), resolve, map gist; (b) #20 live proof from merged main (reinstall
   from a clean `main` after (a)) — record the evidence on #20 as a follow-up comment.
3. Then start the history-UI worker (#27) from a brief modelled on `docs/briefs/history-probe-brief.md` +
   the #9 resolution; it is a production slice (TDD, review chain). It needs a **UI-quality bar** Daniel set:
   Apple-shippable — brief the worker to propose the visual design at Gate A with a screenshot.
4. Worker protocol below; merge discipline; resolution comment + close + map gist per ticket.

## Supervisor role (Daniel's standing instructions, this session)
- **You orchestrate only.** Workers do ALL hands-on work, including prototypes — Daniel rejected the supervisor
  building the prototype itself. You relay between Daniel and workers, gate live runs, review at Gate B, run the
  review chain, merge, and keep the map.
- Terminal-target live checks need no Daniel: workers automate them (see Durable notes) and you verify evidence.
- New worker/reviewer panes go into **new Herdr tabs** (`herdr tab create --cwd … --label … --no-focus`), not splits.

## Models and the review chain (map Notes; unchanged)
- Workers/prototypes: `anthropic/claude-opus-5-5:medium` as **separate Pi instances in Herdr panes** (never subagents).
- Reviewer: **one** fresh `openai-codex/gpt-6-sol:medium` per branch, own pane/tab, detached worktree at the
  branch head, `REVIEW-BRIEF.md` written into that worktree (VERDICT / BLOCKING / NON-BLOCKING / DUPLICATION /
  GAPS / METHOD). Delta re-review = "Delta re-review request" appended to the same file, **fresh** instance
  (stop the old agent; if the pane refuses `agent_pane_busy`, close it and create a new tab).
- **Reviewer prompts must end with a mandatory `intercom send <your-id>` step** — a reviewer told only to
  "write the verdict and stop" finishes silently and you wait forever (happened; Daniel had to relay).
- Supervisor reads the core files at Gate B before approving; author idles during review; after the review post
  a review-chain summary in the resolution comment. Doc-only non-blocking fixes need no further pass.

## Running workers — exact protocol
1. Write the brief into `docs/briefs/`, commit to `main`, `git worktree add -b <branch> ~/.pi/worktrees/jevpaste/<branch> main`.
2. `herdr tab create --cwd <worktree> --label <branch> --no-focus`; read the pane id from the JSON reply.
   Sleep ~3 s, `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model <model>`; sleep ~6 s,
   `herdr agent prompt <name> "First run in bash: env | grep '^PI_MODEL'. Then read docs/briefs/<x>.md … supervisor intercom id <ID>."`
3. Answer a pending `intercom ask` only with `intercom reply` (replyTo = its id); a `herdr agent prompt` queues
   behind it. If a reply fails with "no pending ask", use `intercom send` to the session instead.
4. Gates: A design doc → B `make check` + `wc -l` + proof (supervisor reads core diffs) → C report comment
   (carries what the old per-branch handoff carried) → review → fixes → delta review → merge.
5. Parallel workers: a "Shared files" section per brief; live runs serialized through you.
6. Merge discipline: `git merge --no-ff origin/<branch>` on `main`, `make check` **before** `git push`. If the
   link fails with an undefined-symbol mangling mismatch after adding files, `swift package clean` first
   (documented `FirstClickView` case in `StatusItemPanelParts.swift` — do not remove its explicit `@MainActor`).
7. Resolution comment, close, map gist, pane/tab close, worktree remove, branch delete (probe/prototype branches
   are **kept** as primary sources, never merged).
8. Every commit now runs the staged-snapshot hook: fresh worktree ≈ 56 s first commit (needs `npm ci` + one
   plain `swift build` first), ≈ 10 s + compile incrementally.

## Durable notes (rescued from retired worker handoffs + live sessions)
- `sqlite3`'s `trim()` strips spaces only — compare history rows with `LIKE`, not `trim()`, for multi-line text.
- Chooser behaviours intentionally not test-asserted: close-triggered resign-key firing synchronously,
  Enter+click in one turn, close-before-reply ordering (see `PanelCandidateChooser` reply-once design).
- Herdr automation: `herdr tab focus` from the CLI can silently no-op — gate every synthetic keystroke/trigger
  on a verified `herdr pane get <id>` focused=true + frontmost-app check, abort otherwise (a misdelivery landed
  in the supervisor pane before this gate existed).
- Worker shells have no Accessibility; only the signed bundle can post events. For probe automation, add a
  signal trigger (e.g. SIGUSR1 → same delivery path) to the signed app; discard terminal paste buffers with
  `herdr pane send-keys <pane> C-c`, read verdicts with `herdr pane read <pane> --source visible`.
- Multi-line paste behaviour matrix (evidence for #20/#29): full detail in the
  [#14 report](https://github.com/DanielMulec/jevpaste/issues/14#issuecomment-5801268147). Not measured:
  terminals without bracketed paste would execute lines.

## Wave-5 lessons (new)
- **Fixture rule bit us again:** `JEVPASTE-HIST-ONE alpha.one@example.org` on one line is one whole-line
  Candidate; Jev's gate said no once, yes once. One pure value per line — put the marker on its own line.
- Daniel gets tired late in a session: batch every worker's live steps into **one** block, run it early, and
  ask "stop for tonight?" with a recommendation when the queue grows. Reviews/merges run fine without him.
- Review brief template now lives in this session's history only — reconstruct from `harden`'s pattern:
  VERDICT/BLOCKING/NON-BLOCKING/DUPLICATION/GAPS/METHOD, five specific questions, `make check` required,
  mandatory `intercom send` last step. Delta re-review = appended "Delta re-review request" + fresh instance.
- GPT-6-Sol reviews took ~3 min each on these branch sizes; don't wait on them synchronously.

## Environment facts
- Installed `~/Applications/JevPaste.app` = **merged main 63079ad** (pre-checks in), running, Open-at-Login **ON**
  (SMAppService [enabled, allowed, notified]). The `jevpaste-dev` identity keeps the Accessibility grant.
- `~/Library/Application Support/jevpaste/history.sqlite` (0600) holds synthetic rows, fixtures and rows of
  Daniel's real clipboard — never print it; read only `JEVPASTE-…` rows.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live ~1.1–1.7 s cold, ~0.2–0.5 s warm.
- Worktrees present: research spikes (`jev`, `macos`, `macos-probe`, `quality`, `signing`, `spike-contract`) +
  **`chatgpt-resolver`** (live worker branch, see above). Kept branches, no worktree: `multiline-probe`, `history-probe`.
- `/tmp/jevpaste-chooser.txt`, `/tmp/jevpaste-chooser-test.html`, `/tmp/jevpaste-harden.txt` are stale live-run
  fixtures; recreate per run. **Payload rule:** candidates are whole lines — pure values per line.

## Working with Daniel
- Short numbered questions with a recommended answer; he answers from his phone. Don't answer for him.
- **Spell out steps in plain words** — opaque labels like "L1/L3" confused him twice; describe what to click
  and what to look at, and say *why* a step exists (he liked the trailing-newline explanation).
- Blanket approval for Keychain/Accessibility/toolchain; synthetic payloads only in real apps; he performs ⌘⇧V
  for live runs (`done`/`nothing`/`failed`); expect extra unprompted presses — reconcile against the log, ask,
  don't assume a bug. Open Chrome pages (`data:` URLs), TextEdit files and apps **for** him — never "copy from
  any text editor"; ⌘C and mouse selection interfere in Herdr.
- He cares about naming and correct reasoning; he will challenge shortcuts and per-app hacks (the bundle-pin
  question on #14: scaffolding had to be justified as probe-only).
- Wayfinder governs; refer to tickets by linked title.

## Suggested skills
- `wayfinder` (every session), `pi-intercom` + herdr CLI (workers), `prototype` (ticket 9's worker brief),
  `tdd` + `codebase-design` (briefs for 20 and 33), `diagnosing-bugs` (33 is a root-cause hunt),
  `grilling` + `domain-modeling` (tickets 31, 32 once unblocked), `resolving-merge-conflicts` (multi-worker waves),
  `writing-for-agents` (briefs and this file).
