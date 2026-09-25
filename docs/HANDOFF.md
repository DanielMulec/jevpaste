# Handoff — jevpaste supervisor (v1 shipped; v1.x backlog, next: grilling 36)

Written for a fresh supervisor session that has never seen the previous one. Repo:
`/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main` clean and pushed).
Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking (`gh` authenticated; wiring via
GraphQL `addSubIssue` / `addBlockedBy` with header `GraphQL-Features: sub_issues,issue_dependencies`).

## Context (read, don't re-derive)
- Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1) —
  **read its body first**: Destination, Notes (hard rules, models, review chain), Decisions-so-far, fog, out of scope.
- Glossary `CONTEXT.md`; design docs `docs/design/*.md` (newest: `free-text-target.md`,
  `no-suitable-match-offer.md`); quality gate `docs/quality-gate.md`; signing `docs/signing.md`.
- Worker briefs (templates for new ones): `docs/briefs/*-brief.md` — newest `free-text-target-brief.md` and
  `enter-after-no-match-brief.md` (two parallel production workers with a "Shared files" section — the pattern
  that worked on 2026-09-25). Review brief pattern: see "Models and the review chain" below.
- **Per-branch worker handoffs are retired**: workers fold everything into their ticket **report comment**.

## Where things stand (2026-09-25 evening — 41 and 42 merged in one session, in parallel)
`main` = 9ea1b70 (merge of `enter-after-no-match` on top of 97bb4a4, merge of `free-text-target`), pushed.
Installed `~/Applications/JevPaste.app` = **main 9ea1b70**, running plain (pid changes; no `--accept-signal-trigger`),
Open-at-Login on. **437 tests / 78 suites.** No worker in flight; worktrees are research spikes only.
Resolved this session (both resolution comments carry the review chain and facts forward):
- [Implement Free-text Target via Jev's third question](https://github.com/DanielMulec/jevpaste/issues/41#issuecomment-5837688434)
  — third `free_text` question, threshold 0.8, whole item as Direct Paste; app name + screened window title sent,
  bundle id never; every Jev attempt logs `p=`. Live: Chrome textarea 0.93, Email field 0.04 (excerpt only),
  Herdr 0.95, **ChatGPT 0.87** (spike said 0.96 — real context is thinner), WhatsApp 0.90.
- [Offer Enter to paste everything after No Suitable Match](https://github.com/DanielMulec/jevpaste/issues/42#issuecomment-5837988168)
  — indicator takes key focus only while offering; Enter = whole item, Esc/click-away/⌘⇧V/8 s insert nothing;
  chooser key mechanism extracted into `KeyPanelSession<Answer>` + `PanelKeyView`. **Daniel: 8 s is fine.**
Direct Paste now has all three doorways (single line, Free-text Target, Enter after No Suitable Match).

## Open tickets (all children of the map — one per session, Daniel's order)
| ticket | type | note |
|---|---|---|
| [Don't wake the target app for a Direct Paste](https://github.com/DanielMulec/jevpaste/issues/36) | grilling | **next**; the cold-AX "press again" showed up again 2026-09-25 in ChatGPT (`refused.targetWaking`) and in a fresh Chrome tab (`refused.noEditableTarget` on first press) |
| [Extract typed tokens embedded in lines as Candidates](https://github.com/DanielMulec/jevpaste/issues/31) | grilling | |
| [Make the history panel visually coherent with the status-item menu](https://github.com/DanielMulec/jevpaste/issues/37) | prototype | Daniel: "get the app complete first" |
| [Decide what the secure-field pre-check uses when the OS secure-input flag is absent](https://github.com/DanielMulec/jevpaste/issues/38) | grilling | post-timeline |

## Next session
**Ticket:** [Don't wake the target app for a Direct Paste](https://github.com/DanielMulec/jevpaste/issues/36) —
grilling, unblocked, unclaimed. Read its body, the resolution of
[Restore Smart Paste in the ChatGPT desktop app](https://github.com/DanielMulec/jevpaste/issues/33#issuecomment-5807967937)
(the wake mechanism: `AXEnhancedUserInterface` set once per pid, 5 s window, "Waking…" refusal) and
`Sources/MacInterop/AXFocusSource.swift` / `FocusedTargetResolver.swift`. Then grill Daniel (short numbered
questions, recommended answers). Points to settle: the Direct Paste path needs no field read — but the
**pre-checks** (secure field, `isSecureField`) and the **Bound Target identity** for re-verification do; what
does a single press do when the tree is unreadable (paste blind? refuse? wake-and-retry automatically within
the 5 s?); does the Free-text Target path (needs context) change the answer; and the *fresh Chrome tab*
case (`noEditableTarget`, not `targetWaking`) — same cause or a different one? Resolution → task ticket(s).
Note the evidence from today's logs: `docs/acceptance/run-2026-09-25-free-text.log` (ChatGPT) and
`docs/acceptance/run-2026-09-25-enter-after-no-match.log` (Chrome fresh tab).
Claim first: `gh issue edit 36 --add-assignee @me`. `intercom status` → your id.

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
- Installed `~/Applications/JevPaste.app` = **main 9ea1b70**, running, Open-at-Login **ON**
  (SMAppService [enabled, allowed, notified]). The `jevpaste-dev` identity keeps the Accessibility grant.
- `~/Library/Application Support/jevpaste/history.sqlite` (0600) holds synthetic rows, fixtures and rows of
  Daniel's real clipboard — never print it; read only `JEVPASTE-…` rows.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live ~1.1–1.7 s cold, ~0.2–0.5 s warm.
- Worktrees present: research spikes only (`jev`, `macos`, `macos-probe`, `quality`, `signing`, `spike-contract`).
  Kept branches, no worktree: `multiline-probe`, `history-probe`, `spike/jev-contract` (free-text spike source).
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
- `wayfinder` (every session), `grilling` + `domain-modeling` (ticket 35 now; 36, 31, 38 later), `prototype` (37),
  `pi-intercom` + herdr CLI (workers/reviewers), `tdd` + `codebase-design` (worker briefs), `telegram-bridge` +
  `telegram_attach` (Daniel is on his phone; contact sheets and screenshots go to Telegram),
  `resolving-merge-conflicts` (multi-worker waves), `writing-for-agents` (briefs and this file).

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

## Wave-7 lessons (new)
- **Reviewers want evidence in the committed log, not in the worker's session.** Brief workers: every helper output
  that backs a claim (digests, counts) goes into the run log at run time — redacted, never contents.
- Chrome DevTools MCP `hasFocus()` is emulated: it is **not** a key-window gate. When Daniel is using Chrome, synthetic
  pastes can land in his other window. Gate on frontmost bundle **and** `select_page`/bringToFront, or wait for him.
- `close_page` ids shift — re-list and verify title immediately before closing (a worker closed Daniel's x.com tab).
- Daniel's switching apps mid-run is normal ("that was multiple times me, sorry"); the abort gate handles it — just
  ask for "go" again.

## Icon / image-gen lessons (new)
- pi's `generate_image` (Antigravity, `gemini-3-pro-image`) works from a Herdr worker. Round 1 with "motif ideas" got
  gradient/outline stock icons — Daniel: "all ugly". Round 2 with an explicit **art-direction reference** (Claude app
  icon: one matte colour, one soft solid glyph, explicit negatives: no gradient/outline/shadow/text/3D) landed first
  try. Lead with a style reference and negatives, not motifs.
- Show Daniel a contact sheet (PIL, 4 across) via `telegram_attach`; he picks by number.
- `scripts/make-icon-images.py` regenerates AppIcon + StatusItem{,@2x} deterministically from
  `docs/icon-candidates/round2-2.png`; status glyph gap widened to ~2 px at 1x for 18 px legibility.

## Wave-8 lessons (2026-09-25, two parallel production workers)
- **Parallel production workers work** when the brief pins the shared surface line by line: "you own the first
  guard of `decided(_:)`, the other owns the `finish(.noSuitableMatch)` line; new test files, not edits". Relay
  each Gate A decision to the *other* worker immediately (enum shapes, function names/signatures) so the rebase
  is one fold. Merge whichever is ready first; the second rebases (`--force-with-lease`) and re-installs.
- Ask both workers to name a shared helper identically **before** either codes it (`withoutOuterLineBreaks`).
- A worker launching the app binary from its shell gets `trusted=false`; relaunch via `open … --args`.
- Reviewers found a *loose test fake* (callbacks fired anytime) — a real class of finding; brief reviewers to
  check fakes against the seam's documented contract.
- `intercom reply` fails once the worker's ask has been superseded by a later `send`; fall back to `send`.
- Daniel answers live blocks tersely ("done", "I think it worked") — always have the worker reconcile from
  DOM/log rather than from his words.
