# Handoff — jevpaste supervisor (v1 shipped; v1.x backlog, next: ticket 35)

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

## Where things stand (2026-09-24 night — v1 declared; wave 7 + app icon merged)
`main` = merge of `app-icon` (7a1bee0), pushed. Installed `~/Applications/JevPaste.app` = that `main`, running, Open-at-Login
on, **olive icon + template menu-bar glyph live**. 385 tests / 69 suites. **No worker in flight; no live worktrees
besides research spikes.** Map Notes now carry a dated **"v1 reached"** line; open tickets are the v1.x backlog.
Also this session: [Give JevPaste an app icon and keep the staging bundle out of Launchpad](https://github.com/DanielMulec/jevpaste/issues/39)
— merged; `make install` now swaps atomically and deletes `build/JevPaste.app` (it was the second Launchpad entry).
Resolved this session:
- [Run the real-app acceptance suite](https://github.com/DanielMulec/jevpaste/issues/29) — merged 1040eb6. Matrix
  passes except the Herdr `sudo` cell → [Decide what the secure-field pre-check uses when the OS secure-input flag is
  absent](https://github.com/DanielMulec/jevpaste/issues/38) (grilling, unblocked, **Daniel: post-timeline** — do the
  four wave-7 tickets first). 150 ms target: left as is (Daniel). Trigger stays in `main`. Review chain: two
  GPT-6-Sol passes (unframed digest → fixed + revalidated 7/7; missing log evidence → appended), supervisor final look.

## Open tickets (all children of the map, all now UNBLOCKED — one per session, all with Daniel)
| ticket | type | note |
|---|---|---|
| [Extract typed tokens embedded in lines as Candidates](https://github.com/DanielMulec/jevpaste/issues/31) | grilling | |
| [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35) | grilling | keep independent from #34's single-line rule |
| [Don't wake the target app for a Direct Paste](https://github.com/DanielMulec/jevpaste/issues/36) | grilling | acceptance saw ChatGPT AX go cold after ~4.5 min idle |
| [Make the history panel visually coherent with the status-item menu](https://github.com/DanielMulec/jevpaste/issues/37) | prototype | Daniel: "get the app complete first" |
| [Decide what the secure-field pre-check uses when the OS secure-input flag is absent](https://github.com/DanielMulec/jevpaste/issues/38) | grilling | post-timeline |

Daniel (2026-09-24): "declared done AND we continue" — v1.x tickets proceed one per session.

## Next session — tonight, Daniel is awake and continuing (2026-09-24, ~21:30)
**Ticket:** [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35)
— `wayfinder:grilling`, unblocked, unclaimed. Daniel chose to continue tonight with a fresh supervisor.

1. Read the map body, this file, and the ticket body (it lists the three sub-questions). `intercom status` → your id.
   **Claim** the ticket (`gh issue edit 35 --add-assignee @me`) before any work.
2. Load `grilling` + `domain-modeling`; skim `CONTEXT.md`, `docs/design/direct-paste.md`, `pre-checks.md`,
   `paste-attempt-state-machine.md`, `mac-interop.md` (Target Context fields, what is always collected). Core code:
   `Sources/SmartPasteCore/DirectPaste/DirectPasteRule.swift`, `Values/ScreenedTargetContext.swift`,
   `PasteAttempt/PasteAttemptCoordinator*.swift`. Zoom into closed tickets on demand: #34 (Direct Paste rule 1),
   #32 (the original two-rule ticket Daniel split), #33 (ChatGPT resolver — the evidence that unlabelled targets
   always get "none of these"), #29 (acceptance facts: Jev needs a labelled field; terminals/chat composers → noMatch).
3. **Grill Daniel** (short numbered questions, recommended answer each, plain words; he answers from his phone):
   - What counts as "something to reason about": field label? placeholder (generic "Ask anything" too?)? section
     heading? sibling labels? Surrounding text is always collected, so it can't be the criterion alone.
   - With nothing to reason about and a **multi-line** item: paste the whole item as one Direct Paste (his stated
     intent) — confirm; what about the chooser (never opens on that path?); what does the user see (same ✓?).
   - Do pre-checks (secure field, suspected secret, no editable target) stay on this path? Daniel's standing option:
     drop them if they cause friction; plain ⌘V has none. Recommend: keep secure-field + secret, they are cheap.
   - The ticket asks for the app to **log the context shape** (has-label/has-placeholder/has-heading/surrounding
     chars, never text) — decide whether that is a prerequisite task (a worker adds the log line, Daniel uses the
     app a day, then decide) or whether he decides now from the #33/#29 evidence. Recommend: decide now, log shape
     anyway as part of the implementation.
   - Keep this rule **independent** from rule 1 (single line → Direct Paste); he was annoyed when they were fused.
4. Record: resolution comment (the rule as a precise statement + examples), close, map gist. If the decision yields
   implementation, write a worker brief (`docs/briefs/`, template: `pre-checks-brief.md` / `chatgpt-resolver-brief.md`),
   TDD via seams, live proof automated (Chrome DevTools MCP + Herdr; Daniel only for ChatGPT/WhatsApp, batched
   early). Then the standard review chain and `make install`.
5. One ticket per session. After 35: 36 (don't wake on Direct Paste — overlaps with 35's path, decide together
   only if Daniel wants), then 31, then 37, then 38.

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
- Installed `~/Applications/JevPaste.app` = **main 1040eb6**, running, Open-at-Login **ON**
  (SMAppService [enabled, allowed, notified]). The `jevpaste-dev` identity keeps the Accessibility grant.
- `~/Library/Application Support/jevpaste/history.sqlite` (0600) holds synthetic rows, fixtures and rows of
  Daniel's real clipboard — never print it; read only `JEVPASTE-…` rows.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live ~1.1–1.7 s cold, ~0.2–0.5 s warm.
- Worktrees present: research spikes only (`jev`, `macos`, `macos-probe`, `quality`, `signing`, `spike-contract`).
  Kept branches, no worktree: `multiline-probe`, `history-probe`. `acceptance` deleted after merge.
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
