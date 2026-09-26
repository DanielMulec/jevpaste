# Handoff — jevpaste supervisor (extraction engine decided; next: launch the Narrowing spike + cursor-context workers)

Written for a fresh supervisor session that has never seen the previous one. Repo:
`/Users/danielmulec/Projekte/experiments/jevpaste` (public, `DanielMulec/jevpaste`, no licence; `main` pushed).
Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking (`gh` authenticated; wiring via
GraphQL `addSubIssue` / `addBlockedBy` with header `GraphQL-Features: sub_issues,issue_dependencies`).
Supervisor model: `anthropic/claude-opus-5-5:xhigh`. Daniel **allows the supervisor to read code and probe facts
itself** (2026-09-26: "don't worry about reading code and similar tasks, just do it") — still no hands-on building.

## Context (read, don't re-derive)
- Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1) —
  **read its body first**. Notes now open with the **Jev-first rule**: everything that can be a Jev choice is a Jev
  choice — no yes/no gates, no local classifiers deciding meaning, no field vocabulary, no app names in behaviour.
- **The contract for the next weeks:** [Decide the extraction engine for any-field Smart Paste](https://github.com/DanielMulec/jevpaste/issues/47#issuecomment-5845599979)
  — read the resolution completely (choice-only J, **Narrowing**, each of the 12 inventory rules decided on its own,
  time budget, too-big copies, no app names).
- Glossary `CONTEXT.md`: **Narrowing** new; **Free-text Target retired**; **Direct Paste** = only Enter after No
  Suitable Match; Candidate Chooser opened by Jev's "ask the user". Design docs `docs/design/*.md`; quality gate
  `docs/quality-gate.md`; signing `docs/signing.md`.
- **Both worker briefs are written and committed:** `docs/briefs/narrowing-spike-brief.md` (AFK spike, Python, no
  Swift) and `docs/briefs/cursor-context-brief.md` (production slice, MacInterop). Both take the supervisor's
  intercom id **from the launch prompt** — put yours in (`echo $PI_INTERCOM_SESSION_ID`).
- Per-branch worker handoffs are retired: workers fold everything into their ticket **report comment**.

## Where things stand (2026-09-26 evening — grilling of 47 done; Daniel left the train, workers NOT launched)
`main` pushed (briefs + glossary + this file). Installed app = main **42b37b3** (Wake Wait), unchanged. 456 tests /
81 suites. **No worker in flight** — Daniel said explicitly: do not kick off the workers in the old session.
Kept spike branches: `spike/any-field-extraction` (f850dc5, the harness the Narrowing spike forks from),
`spike/jev-contract`.

Resolved this session: [Decide the extraction engine for any-field Smart Paste](https://github.com/DanielMulec/jevpaste/issues/47#issuecomment-5845599979)
(gisted on the map; "other users on their own ChatGPT login" moved to Out of scope; too-big-copy windowing to fog).

Facts established this session (in the resolution; don't re-derive):
- Jev's documented maximum is **255 options per Choice** (TypeSafe API reference; same on the direct API). Several
  choice questions per request are fine (parallel; no count limit); budget 64k tokens/request, 32k for state + the
  longest question. TypeSafe's own docs recommend "section first, then the span inside it" past 255.
- The **255-character option-description cut is NOT a Jev limit** — an unverified assumption from the first spike.
  Supervisor probe (2 calls): 1,500- and 6,000-character options accepted and read to the end. `Implement
  Narrowing` removes the cut.
- Jev returns a probability per option (`answers.<q>.probabilities`) and a `confidence`; Gateway routing currently
  resolves to DigitalOcean with `typesafe-ai` as fallback.

## Open tickets (children of the map)
| ticket | type | note |
|---|---|---|
| [Spike: does choice-only Narrowing pass the any-field matrix?](https://github.com/DanielMulec/jevpaste/issues/49) | task | **launch now** — fixed 7 criteria in the body |
| [Read nearby text around the text cursor, without an app list](https://github.com/DanielMulec/jevpaste/issues/51) | task | **launch now, in parallel** — independent of the spike |
| [Implement Narrowing](https://github.com/DanielMulec/jevpaste/issues/50) | task | blocked by the spike; brief written **after** the spike reports, from its FINDINGS (design + verbatim wordings) |
| [Make the history panel visually coherent with the status-item menu](https://github.com/DanielMulec/jevpaste/issues/37) | prototype | Daniel: "get the app complete first" |
| [Decide what the secure-field pre-check uses when the OS secure-input flag is absent](https://github.com/DanielMulec/jevpaste/issues/38) | grilling | post-timeline |
| [Decide how JevPaste switches Jev providers from the Vercel AI Gateway to Typesafe direct](https://github.com/DanielMulec/jevpaste/issues/45) | grilling | blocked by 37, 38; sequence it **after** Implement Narrowing (both rewrite `JevGateway`) |

## Next session — exact steps
1. Read the map body, this file, the 47 resolution, both briefs. Ask Daniel "go?" before launching (he left mid-session).
2. Claim both tickets (`gh issue edit 49 --add-assignee @me`, same for 51).
3. Spike worker: `git fetch origin && git worktree add -b spike/narrowing ~/.pi/worktrees/jevpaste/narrowing-spike origin/spike/any-field-extraction`
   — the brief and the new glossary live on `main`, not on that branch, so the launch prompt must say:
   "read `/Users/danielmulec/Projekte/experiments/jevpaste/docs/briefs/narrowing-spike-brief.md`; supervisor intercom id <ID>".
4. Cursor worker: `git worktree add -b cursor-context ~/.pi/worktrees/jevpaste/cursor-context main`; prompt: "read
   `docs/briefs/cursor-context-brief.md`; supervisor intercom id <ID>". Fresh worktree: first commit ≈ 56 s.
5. Both on `anthropic/claude-opus-5-5:high` (Daniel, Q24), each in its own Herdr **tab** (protocol below).
6. **Spike GATE A is yours to check hard:** every wording verbatim, no field or place types anywhere (Daniel checks
   too), no local rule deciding meaning, no piece dropped. Relay approval; then let it run (free-tier 429s make it
   slow; budget ≤ 900 calls; runner resumable).
7. Any failed spike criterion → Daniel before any Swift, in plain words; **no silent fallback** to a yes/no (the
   known risk: Jev may not pick the whole copy in chat boxes — Q9).
8. Spike passes → write `docs/briefs/narrowing-brief.md` for Implement Narrowing (with a "Shared files" section if
   cursor-context is still open; both may touch `TargetContext` plumbing only if the cursor slice changes it).

## Model rule change (2026-09-25)
Research now runs on **`anthropic/claude-opus-5-5:high` as a Herdr worker** (high since 2026-09-26) (own tab + Pi instance, brief in
`docs/briefs/`, e.g. `typesafe-direct-research-brief.md`), not a subagent and not DeepSeek Flash. Daniel did not
recognise the Flash line; it was a cost choice from before Opus 5.5 existed. Map Notes updated. A `subagent` launch
on Flash was stopped and redone this session — don't repeat.

## Supervisor role (Daniel's standing instructions, this session)
- **You orchestrate only.** Workers do ALL hands-on work, including prototypes — Daniel rejected the supervisor
  building the prototype itself. You relay between Daniel and workers, gate live runs, review at Gate B, run the
  review chain, merge, and keep the map.
- Terminal-target live checks need no Daniel: workers automate them (see Durable notes) and you verify evidence.
- New worker/reviewer panes go into **new Herdr tabs** (`herdr tab create --cwd … --label … --no-focus`), not splits.

## Models and the review chain (map Notes; unchanged)
- Workers/prototypes/research: `anthropic/claude-opus-5-5:high` as **separate Pi instances in Herdr panes** (never subagents). Daniel moved workers from medium to high on 2026-09-26 after reading a medium worker's reasoning mid-spike ("a bit distrusting").
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
- Installed `~/Applications/JevPaste.app` = **main 42b37b3**, running, Open-at-Login **ON**
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

## Wave-9 lessons (2026-09-25, Wake Wait)
- Gate A *measurement before design* worked: 8 probe runs settled the Chrome question in 5 minutes and let the worker
  drop legacy code (wake walk, per-pid window) with evidence.
- Review found "deadline computed after synchronous work" — brief workers to capture the instant a clock starts *from*
  and derive timers from it, not `clock.now` at scheduling time.
- Review found the fake presenter firing cancel callbacks unconditionally (second time this class appears): fakes must
  model visible state; brief it explicitly.
- `herdr tab close`/`git worktree remove` in one chained command may abort mid-way but the earlier steps stick —
  verify with `git worktree list` / `git ls-remote` rather than re-running blindly.
- Daniel wants to be asked before any model that isn't in the map Notes; and if a Notes line surprises him, explain
  where it came from before acting.

## Wave-10 lessons (2026-09-26, grilling 31 + research 48)
- **Daniel pushes back hard on scope-shrinking recommendations** ("13 isn't an answer, 13 is me pushing back because
  you're clashing too hard"). When he says he wants *anything*, reframe the ticket to his goal and offer engines to
  compare — don't re-argue the small version. A spike with numbers is the answer he accepts.
- He reads "token" as an LLM token — glossary now says **Embedded Value**. Explain Jev as "a chooser, not a writer:
  it can only pick what we hand it" — that one sentence unlocked the whole J design for him.
- Research on Opus 5.5 high finished in ~16 min with citations; mid-run supervisor additions via `intercom send`
  worked (Codex SDK angle, ChatGPT-generated claims to verify). Verify claims he pastes from ChatGPT — treat as a
  claim list, never as a source.
- Gateway `/v1/models` is a cheap fact check (390 models; Flash + Luna both routed) — look up, don't ask.

## Wave-11 lessons (2026-09-26, any-field spike)
- **Daniel's core rule, learned the hard way: never put a yes/no in front of Jev when a choice can do it.** The
  supervisor added a "contains more?" boolean gate to save a call; it was wrong 17/100 and unstable, and cost the
  spike its pass. Choice was 52/52. He was angry ("why do I need to fight for things like this") — treat any new
  local gate, classifier or cap as a decision to justify to him, not a default.
- He reads "token" as LLM token → **Embedded Value**; "negatives" confused him → say "trap cells where the right
  answer is nothing"; "cutting" → "scissors cut at every point and hand Jev all pieces; Jev is the only reader".
- Gate prompt examples must never name field types (v6 withdrawn mid-run for "postcode, email…"); he checks.
- Opus 5.5 high worker: reviewed the medium worker's files critically and found real fixes; mid-run supervisor
  additions via `intercom send` worked; it wrote a resumable runner on its own. Killing a background `python3 -u
  run.py matrix` needs `pkill -9` (plain pkill hit the bash wrapper only).
- Laptop lid / train tunnels kill both worker and supervisor turns; state on disk survived every time — prompt
  the worker to "resume where you were" with the row count.
- Gateway has no credits (403 on non-Jev models); Codex CLI rejects `gpt-6-luna`; gpt-5.6-luna via Codex ≈ 7 s/call.

## Wave-12 lessons (2026-09-26, grilling 47 on Opus 5.5 xhigh)
- Daniel: "Do not care about my feelings, care about what is best for the product as a Jev-first product, making it
  easy for anyone to smart paste on macOS." Give the product-best answer firmly, with reasons; he asks for it.
- When a rule gets decided, **grep the code for the whole class** (he asked "what else are you withholding" last
  time): this session surfaced the terminal bundle-id list and the password-manager vendor tags unprompted. He then
  ruled: no app names in behaviour anywhere.
- **Verify inherited limits before repeating them.** The 255-character option cut had travelled through spike code,
  Swift, design docs and my own round-2 answer as "Jev's limit"; the docs never said so and a 2-call probe disproved
  it. Check TypeSafe's `llms-full.txt` (`curl -s https://docs.typesafe.ai/llms-full.txt`) and probe cheaply.
  Python's urllib fails TLS here; use `curl` with the key written to a 0600 header file, then delete it.
- Grilling rounds of 6–14 numbered questions with a recommendation each worked; answers come back as
  "Deal/Ok/Agree". A **conditional** answer ("If Jev can do that, ok") signals a misunderstanding — clarify.
- Keep independent rules as separate numbered questions, even when they share a reason (headings vs `Label:`).
- Handoff lives in `docs/HANDOFF.md` (Daniel overrides the handoff skill's temp-dir default) and is written only
  after tickets and briefs exist. This session hit ~250k context during grilling — hand off earlier next time.

## Suggested skills (next session)
`wayfinder` (every session), `pi-intercom` + Herdr CLI (launching and gating workers), `writing-for-agents` (the
Narrowing build brief), `codebase-design` + `tdd` (reviewing Gate A/B of cursor-context, briefing Narrowing),
`domain-modeling` (keep `CONTEXT.md` in step if the spike changes a term), `grilling` (if a spike criterion fails
and Daniel must decide), `telegram-bridge` + `telegram_attach` (Daniel is often on his phone).

