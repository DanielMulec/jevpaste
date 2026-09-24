# Handoff — jevpaste supervisor (Wayfinder map in execution phase, wave 7 = acceptance suite)

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

## Where things stand (2026-09-24 evening — wave 6 closed, wave 7 = acceptance suite started)
`main` @ c3ee822+ (last: handoff). Worker branch `acceptance` = origin @ **5c2ef17** (worker idle at GATE B). Installed `~/Applications/JevPaste.app` = **clean main aeb2dd9**
(Direct Paste + history UI), running, Open-at-Login on. 379 tests / 68 suites. Resolved this session:
- [Implement Direct Paste for single-line items](https://github.com/DanielMulec/jevpaste/issues/34) — merged f8ce110;
  live-proven Chrome ×2, Herdr shell ×2 (trailing newline stripped, nothing executed), ChatGPT composer, two-line
  regression. Review APPROVE 0 blocking (2 nits applied, no delta pass).
- [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27) — merged aeb2dd9; 9 functional steps
  live-proven; **look judged "No" by Daniel** → [Make the history panel visually coherent with the status-item menu](https://github.com/DanielMulec/jevpaste/issues/37)
  (prototype, blocked by #29, deferred: "get the app complete first"). Review APPROVE → 2 nits fixed → delta APPROVE.
- New: [Don't wake the target app for a Direct Paste](https://github.com/DanielMulec/jevpaste/issues/36) (grilling,
  blocked by #29) — cold-AX wake fired on a Direct Paste; pointless on that path.

**One worker in flight:** [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29) —
branch `acceptance` @ 5c2ef17, worktree `~/.pi/worktrees/jevpaste/acceptance`, Herdr tab `acceptance` (pane wC:p1Q-ish — check `herdr agent list`), worker intercom `01a0d47a-b3d1-7342`, brief
`docs/briefs/acceptance-suite-brief.md`. **GATE A approved by Daniel (option 1)** — flag-gated `SIGUSR1` trigger stays in `main` behind
`--accept-signal-trigger` (`Sources/JevPasteApp/Launch/AcceptanceTrigger.swift`, 52588e9). **GATE B approved** —
automated matrix done @ 9f30b18 (`docs/acceptance/results.md`): 22 presses over Chrome (DevTools MCP), Herdr,
TextEdit; **one failed cell: a `sudo` Password: prompt inside a Herdr pane does not engage macOS secure input, so
the secure-field pre-check did not refuse (single line Direct-Pasted into the buffer, not submitted); plain Ghostty
control refused correctly → Herdr-specific gap** → becomes a ticket after the suite. Responsiveness: Jev indicator
159–181 ms (timer starts at 150 ms by design), Jev inserts 380–729 ms warm / 1339 ms cold, Direct Paste ✓ 128–154 ms.
**Remaining: the Daniel block (~6 min, staged, worker idle):** Chrome chooser Esc (C), history-select → Rejev-paste
(G), WhatsApp "Message yourself" and ChatGPT composer (A + trailing \n, multi-line, secret). Then GATE C report. **Automation rule (Daniel):** the worker
does everything it can alone — **Chrome via the Chrome DevTools MCP server** (`chrome-devtools` in
`~/.pi/agent/mcp.json`, `npx chrome-devtools-mcp@latest --channel=stable --auto-connect`, lazy: `mcp({connect:…})`
first; verified 2026-09-24: lists Daniel's real tabs, opens/snapshots/closes a `data:` page), terminals via Herdr,
TextEdit via `open`. Daniel only for WhatsApp and ChatGPT, in one batched block. GATE A decides the **⌘⇧V trigger**
for unattended runs (proposal: `SIGUSR1` → hotkey handler, behind a launch flag, as `multiline-probe` did) — Daniel
must approve it as test scaffolding.

## Open tickets (all children of the map)
| ticket | type | state |
|---|---|---|
| [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29) | task | claimed, GATE B passed, Daniel block pending |
| [Extract typed tokens embedded in lines as Candidates](https://github.com/DanielMulec/jevpaste/issues/31) | grilling | blocked by 29 |
| [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35) | grilling | blocked by 29 |
| [Don't wake the target app for a Direct Paste](https://github.com/DanielMulec/jevpaste/issues/36) | grilling | blocked by 29 |
| [Make the history panel visually coherent with the status-item menu](https://github.com/DanielMulec/jevpaste/issues/37) | prototype | blocked by 29 |

## Next session — in order
1. Read the map body and this file. `intercom status` → your id (this session's `01a0d43b` is dead; tell the
   worker the new id first thing).
2. `herdr agent list`: `acceptance` alive → `intercom send 01a0d47a-b3d1-7342 "new supervisor id <ID>. Daniel is
   here — stage the Daniel block (step 4)"`. Dead → `herdr tab create --cwd ~/.pi/worktrees/jevpaste/acceptance
   --label acceptance --no-focus`, start pi `anthropic/claude-opus-5-5:medium`, prompt "read
   docs/briefs/acceptance-suite-brief.md; branch acceptance is at 5c2ef17, GATE A+B approved; stage the Daniel
   block (step 4); supervisor intercom id <ID>".
3. Relay the Daniel block in plain words (four parts: C, G, WhatsApp, ChatGPT); "move the mouse to the top edge"
   for anything under the menu-bar icon; he must not ⌘C during it. Then GATE C (report), then file the Herdr
   secure-prompt finding as a ticket (grilling: what should the secure pre-check use when the OS flag is absent —
   a no-echo heuristic? a terminal-specific rule? Daniel dislikes per-app hacks) blocked by nothing.
4. Review (fresh GPT-6-Sol, REVIEW-BRIEF.md pattern below), merge, resolution, map gist, cleanup, reinstall main.
5. Then the four blocked tickets open at once — all grilling/prototype with Daniel; one per session.

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

## Chrome DevTools MCP (new 2026-09-24, Daniel-approved)
- `~/.pi/agent/mcp.json` now has `chrome-devtools`: `npx -y chrome-devtools-mcp@latest --channel=stable
  --auto-connect --no-usage-statistics` (official Google package, github.com/ChromeDevTools/chrome-devtools-mcp;
  `@latest` self-updates; previous file backed up as `mcp.json.bak`). Lazy in pi: `mcp({connect:"chrome-devtools"})`
  first, then ~30 tools (`list_pages`, `new_page`, `select_page`, `take_snapshot`, `click`, `fill`,
  `evaluate_script`, `close_page`). Attaches to Daniel's **running** Chrome and drives his real tabs — verified.
- **Standing instruction (Daniel):** workers automate every Chrome step through it and every terminal step through
  Herdr; he is only needed for WhatsApp/ChatGPT (and chooser/history UI clicks). Brief every worker accordingly.
- The `--accept-signal-trigger` / `SIGUSR1` press path (`Sources/JevPasteApp/Launch/AcceptanceTrigger.swift`) is
  approved to live in `main` as test scaffolding (off by default) so unattended runs can fire ⌘⇧V.

## Environment facts
- Installed `~/Applications/JevPaste.app` = **clean main aeb2dd9** (Direct Paste + history UI in), running, Open-at-Login **ON**
  (SMAppService [enabled, allowed, notified]). The `jevpaste-dev` identity keeps the Accessibility grant.
- `~/Library/Application Support/jevpaste/history.sqlite` (0600) holds synthetic rows, fixtures and rows of
  Daniel's real clipboard — never print it; read only `JEVPASTE-…` rows.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live ~1.1–1.7 s cold, ~0.2–0.5 s warm.
- Worktrees present: research spikes (`jev`, `macos`, `macos-probe`, `quality`, `signing`, `spike-contract`) +
  `chatgpt-resolver` (stale, merged — remove) + **`acceptance`** (live worker). Kept branches, no worktree: `multiline-probe`, `history-probe`.
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

## Wave-6 lessons (new)
- **Payload rule, again:** `JEVPASTE-LIVE-33 synthetic test line` is a sentence, not a value — Jev refused it and a
  press was wasted. Live payloads are pure values (`live33@example.org`) and, for Jev runs, the field is labelled.
- **Jev needs a labelled field.** In unlabelled targets it says no to everything; do not read that as a resolver or
  insertion bug. Direct Paste (single line) is now the path into ChatGPT/terminals.
- Bare `swift test` fails to link (`_TestingInterop`); use `make test`.
- `gh issue comment --body "$(cat <<'EOF' …)"` breaks on apostrophes in bash; write the comment to a file and use
  `--body-file`.
- Daniel wanted two *separate* rules (single line; nothing to reason about) — a ticket that fuses them as one
  question with sub-cases annoyed him. Keep independent rules independent in the write-up.

## Wave-6 lessons, second half (new)
- Review brief pattern that worked twice tonight: detached worktree at the branch head, `REVIEW-BRIEF.md` with
  "What the branch claims", "Required method" (make check, read all changed files, five specific questions with
  file:line, tests via seams), verdict format, mandatory `intercom send`. Delta re-review = append "Delta re-review
  request" to the same file, stop the old agent, **new tab + fresh instance**, prompt "handle ONLY the delta section".
- Reviewers may need `npm ci --ignore-scripts` before `make check` (jscpd) — say so in the brief.
- Daniel's menu bar auto-hides: he rarely sees the ✓; the log is the proof of outcome. Say "move the mouse to the
  top edge" whenever a note under the icon matters.
- He clicks away instead of pressing Esc, and copies things between staging and pressing — reconcile against the
  log, don't call it a defect; ask him not to ⌘C during a live block.
- Scripts with arrow keys: the history list is newest-first — "↑ to reach an older row".
- `gh issue create --body-file` + GraphQL `addSubIssue`/`addBlockedBy` occasionally 503 — retry once.
