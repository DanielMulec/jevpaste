# Handoff — jevpaste orchestrator (Implement Narrowing: Gate B passed, live run found two chooser problems → diagnose, then Daniel decides)

Written for a fresh orchestrator session (`anthropic/claude-opus-5-5:xhigh`; **check `env | grep '^PI_'` first**:
`PI_MODEL=claude-opus-5-5`, `PI_REASONING_LEVEL=xhigh`, provider anthropic). Repo: `/Users/danielmulec/Projekte/experiments/jevpaste`
(public, `DanielMulec/jevpaste`, no licence; `main` pushed). Owner: Daniel Mulec. Tracker: GitHub Issues with native
sub-issues + blocking (`gh` authenticated; wiring via GraphQL `addSubIssue` / `addBlockedBy` with header
`GraphQL-Features: sub_issues,issue_dependencies`). Workers: fresh `anthropic/claude-opus-5-5:high` Pi instances in
Herdr tabs. Your intercom id: `echo $PI_INTERCOM_SESSION_ID` — it is **not** the id written in the brief (see step 2).

## Context (read, don't re-derive)
- Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1): **read
  its body first** (Notes: **Jev-first rule**, **Orchestrator latitude**, **Chrome rights**, new **Other users** line).
- Ticket in flight: [Implement Narrowing](https://github.com/DanielMulec/jevpaste/issues/50) (assigned to Daniel = the claim).
  Brief `docs/briefs/narrowing-brief.md`; design as built `docs/design/narrowing.md` (branch `narrowing`).
- **Worker handoff (read it fully):** `docs/briefs/narrowing-worker-handoff.md` on branch `narrowing` (worker 2 wrote
  it at ~331k context). Worker 1's older handoff with the **Gate A reply verbatim**:
  `~/.pi/worktrees/jevpaste/narrowing-handoff.md` (outside the repo) + stash `~/.pi/worktrees/jevpaste/narrowing-handoff-stash/`.
- Live-run log: `docs/acceptance/run-2026-09-26-narrowing.log` (branch `narrowing`).
- Contract: [Decide the extraction engine for any-field Smart Paste](https://github.com/DanielMulec/jevpaste/issues/47#issuecomment-5845599979);
  spike: [Spike: does choice-only Narrowing pass the any-field matrix?](https://github.com/DanielMulec/jevpaste/issues/49)
  (data on branch `spike/narrowing` @ ba32886).

## Where things stand (2026-09-26, ~20:45)
- **Branch `narrowing`** (worktree `~/.pi/worktrees/jevpaste/narrowing`), pushed. Commits: 9e2a6d4 design → d81c604
  code+tests+fixtures → 6958ebd replay 14 cells → b117e47 docs → 568c96d README privacy → 7e4d172/da75606 live log →
  **1c06af2 fix (A)** → worker 2's handoff commit. `make check` green (442 tests, 3.4 s); `make planning-time` (release)
  within ceilings (recorded pastes ≤ 5 ms, 300-line list 32 ms, 3000-line copy 72 ms — worker 2 fixed an O(n²) search
  that had made planning take 83 s).
- **Gate A approved** (wordings byte-checked by me against FINDINGS; condition 1 "one JSON writer" = `OrderedJSON.rendered`
  in Core, met; condition 2 fixtures ignored by make check, met). **Gate B approved** (I ran make check + planning-time
  and read Narrowing.swift, FollowUp.swift, +Narrowing coordinator, JevRefusal, JevGatewayDecisionService).
- **Live run so far** (installed build = **branch 568c96d**, i.e. WITHOUT fix (A)): (b) Herdr lone URL → whole URL, not
  executed, 1.25 s cold; (d) 3000-line copy → sent, Jev 400 → "Too long for Smart Paste", nothing inserted; (a) Chrome form:
  Ort → `Graz`, E-Mail ← signature → the address, Kommentar → whole copy (p=0.56), Telefon → offer timed out, empty.
  (c) 300-line list with trailing newline → **"Too long"** — root cause: the stripped whole copy was offered as a child,
  a byte-identical duplicate of *keep* (spike fixtures never had trailing newlines). **Fix (A), Daniel "Agree"**: no child
  equals what keeping its parent pastes → 1c06af2, tested, replay byte-identical, **not installed yet**.
  **(B), Daniel "Agree"**: a follow-up that fits no size form still sends the last form and Jev refuses → record for Gate C
  and the later Narrowing round, no fix now. Also for Gate C: the size model says a 350-line list doesn't fit one call
  while 300 and 400 do (grouping not monotonic).
- **Daniel's block, step 1 (two emails → chooser) FAILED in two ways** (screenshot on his Desktop,
  `Bildschirmfoto 2026-09-26 um 20.35.57.png`; log 20:35:42–20:36:02, 1 question, 92 options, ask_user p=0.51):
  (1) the chooser listed 6 rows: address 1, three multi-line pieces of the copy (whole copy, its stripped duplicate —
  gone with (A) — and a 3-line run) and two **fragments** of address 2 (`holzner@studio-`, `.example`);
  (2) **the full second address was not listed at all**; Daniel picked the fragment and exactly that was inserted.
  The spike's criterion 4 only checked *that* ask_user was chosen, never *what* the chooser lists — a measurement gap.
  Steps 2+3 (WhatsApp / ChatGPT whole copy) **not run**.
- Handovers this session: worker 1 → worker 2 at ~460k context (clean, ~2 min, tarball backup
  `~/.pi/worktrees/jevpaste/narrowing-wip-1832.tar.gz`); worker 2 → (next) at ~331k; this orchestrator at ~200k.
- **Tracker changes this session:** Implement Narrowing assigned to Daniel (it had no assignee);
  [Decide how JevPaste supports Typesafe direct alongside the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/45)
  retitled; body: **addition, not replacement; every user picks the provider in the app's settings** (Daniel), open:
  key entry/storage, missing-key behaviour, fit with the history-panel UI ticket; [Daniel's comment](https://github.com/DanielMulec/jevpaste/issues/45#issuecomment-5847682270).
  Map Notes gained **Other users**: others run JevPaste from the public repo with their own key; "no bigger plans yet"
  (onboarding, notarized distribution, public release stay out of scope; licence stays in the fog).

## Open tickets (children of the map)
| ticket | type | note |
|---|---|---|
| [Implement Narrowing](https://github.com/DanielMulec/jevpaste/issues/50) | task | in flight; next: F1 diagnosis |
| [Decide how JevPaste supports Typesafe direct alongside the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/45) | grilling | after Narrowing; settings UI is new (app has none) |
| [Make the history panel visually coherent with the status-item menu](https://github.com/DanielMulec/jevpaste/issues/37) | prototype | after 45 |
| [Decide what the secure-field pre-check uses when the OS secure-input flag is absent](https://github.com/DanielMulec/jevpaste/issues/38) | grilling | post-timeline |

## Next session — exact steps
1. `env | grep '^PI_'`. Read the map body, this file, the brief, `docs/design/narrowing.md`, the worker handoff
   (`git -C ~/.pi/worktrees/jevpaste/narrowing show HEAD:docs/briefs/narrowing-worker-handoff.md`).
2. **Launch worker 3** in the same worktree (no new worktree): `herdr tab create --cwd ~/.pi/worktrees/jevpaste/narrowing
   --label narrowing-3 --no-focus`; `herdr agent start narrowing3 --kind pi --pane <id> --timeout 60000 -- --model
   anthropic/claude-opus-5-5:high`; prompt: "First run env | grep '^PI_MODEL' and '^PI_REASONING'. You are the THIRD worker
   on this slice. Read docs/briefs/narrowing-brief.md, docs/design/narrowing.md, docs/briefs/narrowing-worker-handoff.md
   (and the Gate A reply in ~/.pi/worktrees/jevpaste/narrowing-handoff.md). Your supervisor intercom id is **<YOUR ID>** —
   it overrides the id written in the brief and the handoffs. Do not reset or discard anything. Start with the F1
   diagnosis; send me one line when you've read everything." (Worker 2's tab `narrowing-2` is already closed.)
3. **F1 diagnosis (worker):** rebuild the exact step-1 request (copy + the form's Target Context are deterministic),
   run it live ~5× in the ids form and ~5× in the full-text form (synthetic data, ~$0.0003/call), print per option: text,
   p. Questions: why does the full second address get no weight while its fragments do (hypothesis: excerpt-id
   confusion — weight landing on ids near the line's id)? What would the chooser list under candidate rules?
4. **Take the finding to Daniel** as short numbered questions with a recommendation each. It is **his** decision: the
   chooser list rule (today: every option with p > 0) and any design change to the option form; any threshold/cap is
   a local rule under the Jev-first rule → justify it. Never tune for the fixture alone.
5. Then: install (ask the worker; `make install`), re-run (c) + Kommentar, then **Daniel's block in one go**: step 1 again,
   steps 2+3 (WhatsApp, ChatGPT) — the worker **stages every copy itself** (pbcopy + verify the history row); Daniel only
   presses ⌘⇧V. Report → **Gate C** → one fresh GPT-6-Sol review (brief pattern below) → fixes → delta review → merge
   (`make check` before push) → `make install` of main → resolution comment (review-chain summary; call it the Narrowing
   **beta**; list (B), the 350-line finding, the chooser finding) → close → map gist → close tabs, remove the worktree,
   delete the branch; delete `~/.pi/worktrees/jevpaste/narrowing-handoff*` and `narrowing-wip-*.tar.gz` after the merge.
6. Then the frontier: the Typesafe-direct grilling (grilling + domain-modeling; the settled points are in its body),
   then the history-panel UI prototype. The map fog "Narrowing accuracy after the beta" comes only after those.

## Installed app right now
`~/Applications/JevPaste.app` = **branch build 568c96d** (Narrowing beta without fix (A)), running normally (no trigger
flag), Open-at-Login ON. If Daniel's daily use suffers before the merge, reinstall main (`make install` from the main
checkout) — orchestrator latitude covers that; tell him.

## Orchestrator latitude (Daniel, 2026-09-26; also in the map Notes)
Daniel: "I gave you the blessing to do tasks relevant for proper orchestration just yourself without asking me."
**Do these yourself, without asking:** read code, probe facts cheaply (docs, `curl`, 1–2 Jev calls), check worker
evidence, stop or kill runaway runners, short evidence runs and cleanups, merges plus `make check`, installs of
merged `main`, tracker and map upkeep, closing tabs and worktrees. **Workers still do** product building, spikes,
prototypes and research. Decisions that belong to Daniel (product behaviour, new gates or classifiers, anything the
Jev-first rule touches) still go to him.

## Model rule change (2026-09-25)
Research now runs on **`anthropic/claude-opus-5-5:high` as a Herdr worker** (high since 2026-09-26) (own tab + Pi instance, brief in
`docs/briefs/`, e.g. `typesafe-direct-research-brief.md`), not a subagent and not DeepSeek Flash. Daniel did not
recognise the Flash line; it was a cost choice from before Opus 5.5 existed. Map Notes updated. A `subagent` launch
on Flash was stopped and redone this session — don't repeat.

## Supervisor role (Daniel's standing instructions)
- **You orchestrate; workers build.** Workers do product building, spikes, prototypes and research. Daniel rejected
  the supervisor building a prototype itself. You relay between Daniel and workers, gate live runs, review at
  Gate B, run the review chain, merge, and keep the map. **Orchestration tasks you do yourself without asking**
  (see "Orchestrator latitude" above).
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

## Chrome DevTools MCP (2026-09-24; full rights granted 2026-09-26 — see Wave-13)
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
- Installed app: see "Installed app right now" above. Open-at-Login **ON** (SMAppService [enabled, allowed, notified]).
  The `jevpaste-dev` identity keeps the Accessibility grant.
- `~/Library/Application Support/jevpaste/history.sqlite` (0600) holds synthetic rows, fixtures and rows of
  Daniel's real clipboard — never print it; read only `JEVPASTE-…` rows.
- Jev key at `~/.config/jevpaste/env` (never print). Jev live ~0.5–1.4 s cold, ~0.6 s warm per call (round 2).
  **Gateway on the paid tier** since 2026-09-26 ~17:05 ($10 of credits; no free-tier 429s any more).
- Worktrees present: `narrowing` (branch `narrowing`, in flight) + research spikes (`jev`, `macos`, `macos-probe`,
  `quality`, `signing`, `spike-contract`). Kept branches, no worktree: `spike/narrowing` (rounds 1+2), `multiline-probe`,
  `history-probe`, `spike/jev-contract`, `spike/any-field-extraction`, `cursor-context-probe`.
- `/tmp/jevpaste-chooser.txt`, `/tmp/jevpaste-chooser-test.html`, `/tmp/jevpaste-harden.txt`, `/tmp/jevpaste-cursor-51/`
  are stale live-run fixtures; recreate per run. **Payload rule:** candidates are whole lines — pure values per line.

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

## Wave-13 lessons (2026-09-26, cursor-context + Narrowing round 1, Daniel partly AFK)
- **Chrome consent sheet.** Every new chrome-devtools MCP connection can raise Chrome's "Remote-Fehlerbehebung
  zulassen?" / "Allow remote debugging?" sheet. **Never kill the MCP process that raised it:** the sheet stays but
  its buttons go dead (Daniel had to press Esc twice). Once Daniel had clicked "Zulassen" (~14:25), later
  connections from new Pi instances attached **without** a prompt. If a worker's MCP calls hang, suspect the sheet:
  take a `screencapture` and ask Daniel; while the sheet is open, Chrome's AX focus reads `AXSheet`.
- **Daniel granted full Chrome rights** ("take all the Chrome rights, do it all freely"). Workers may drive his
  Chrome, but only in their own tabs. Re-list pages and check the URL before `close_page`.
- **Relaunch order after a live run:** restore the clipboard vault **before** `open ~/Applications/JevPaste.app`.
  Otherwise Launch Adoption adopts the test fixture as the Active Item (it happened once, with a synthetic secret).
- **Committed logs carry no literal text:** no pane lines, no `user@host` prompts, no window or sheet titles, no
  fixture prefixes, no `/Users/<name>` paths. The reviewer blocked the merge on exactly this. Brief workers on it
  explicitly.
- **Signals by pid only.** `pkill -USR1 JevPaste` would also hit production, which has no USR1 handler unless it
  was launched with `--accept-signal-trigger`, and the default action terminates it.
- **ChatGPT.app now reports bundle id `com.openai.codex`.** It doesn't matter since no app names are in behaviour.
- **Free-tier Jev is slow for matrices:** about 1.8 pastes per minute because of 429 waits. Workers wait in long
  `sleep N` chunks, and a queued intercom message only lands after the sleep. To get through sooner, kill the
  child (`pkill -f "sleep N"`); the worker then reads the message.
- **Jev size facts (round 1, measured):** one question plus a copy is accepted up to 800 log lines (32,869 input
  tokens) and refused from 806 lines with HTTP 400. The body is `{"error_type":"max_tokens_exceeded"}` or
  `typesafe returned status 400` when the Gateway falls back. **The state counts once across parallel questions:**
  3 questions at 56.9k OK, 4 at ~71k refused.
- **Jev's weakness (round 1):** it is excellent when the exact answer is among the options. It is poor at
  "choose the smallest option that contains it" and at weighing the whole copy against an attractive part.
  Design so that the exact piece is offered.
- Daniel sometimes sends a skill's text by accident (twice today the `wayfinder` skill with no message, or with a
  "that was an accident" follow-up). Treat a skill-only message as no instruction and ask.
- Daniel was AFK for a long stretch and didn't read Telegram. Telegram summaries are fine, but repeat the essentials
  when he's back.

## Wave-14 lessons (2026-09-26, Narrowing round 2, Daniel AFK most of the afternoon)
- **Check `PI_MODEL` at session start** and say so if it isn't the map's orchestrator model. `/model <id>` inside the
  session switches it without losing context or the intercom id; a new session would orphan the worker's messages.
- **Read the Gateway's routing before blaming anyone for a 429.** The free tier's 429 said "The upstream provider is
  currently experiencing high demand" but carried `providerAttemptCount: 0` — the Gateway refused it itself. I first
  inferred the opposite from the message text and had to correct a ticket comment. A 30-call parallel burst of a
  1-option choice (~$0.0003) is the cheap test.
- **Stop a doomed matrix before the held-out cells run.** Held-out cells are spent once they have seen a design; a
  design change after Gate A = Gate A2 (verbatim diff, updated tuned-on list) + full re-run. Test levers **alone** in
  their own requests: several variants in one request contaminated each other (the state is shared).
- **Every option Jev weighs should be presented the same way.** A keep option without visible text lost to
  near-duplicate children that had text.
- **Workers sleep in 25–30-minute chunks** during free-tier matrices; an intercom message waits until the sleep ends.
  `pkill -f "sleep <N>"` delivers it. On the paid tier, brief workers to poll every 2–3 minutes.
- **Implementation bugs found mid-matrix** (not design changes) get a targeted re-run of the affected cells only, as
  their own labelled phase; the frozen design text decides which it is.
- The pre-commit hook prints ~1,700 lines of test output — redirect it to a file.
- Daniel asked for summaries "in human warm language" on Telegram: plain sentences, what happened, what's next, what
  he needs to decide, numbered, with a recommendation each. He asked whether each long re-run was necessary — explain
  why in one screen when runs repeat.
- This session reached ~270k context; the handoff was written before Daniel's answers arrived.

## Wave-15 lessons (2026-09-26 evening, Narrowing build)
- **Worker context handovers work:** at ~460k (and again ~331k) the worker wrote a handoff (Gate A reply verbatim,
  per-scope status, uncommitted files, traps), a fresh worker continued in the same worktree within minutes. Daniel
  wants handoffs **in the docs folder** (`docs/briefs/<slice>-worker-handoff.md`, committed on the branch). When the
  code can't be committed yet (periphery strict rejects test-only internal code), tar the worktree first.
- **Give performance targets in milliseconds.** Planning is synchronous Core work on the main actor: it blocks the
  150 ms indicator and click-cancel. Ceilings set: ordinary ≤ 20 ms, 300-line ≤ 100 ms, too-big ≤ 250 ms (release).
- **Spike fixtures vs real copies:** the spike's copies never ended with a line break; real copies do. That hid a
  duplicate-of-keep option. When porting a spike, ask which real-world shapes its fixtures lacked.
- **Spike criteria can pass without measuring the product:** "ask_user chosen" passed while the chooser list itself
  was junk. Check what the user will *see* for every outcome kind, not only the pick.
- **Stage copies for Daniel.** A worker wrote "Copy these four lines" for Daniel — he can't copy from the TUI. Workers
  pbcopy the fixture, verify JevPaste's newest history row digest, then Daniel only presses ⌘⇧V.
- **Chrome's "Allow remote debugging?" sheet came back** (19:02) for a new worker's first MCP connection despite the
  earlier approval — Wave-13's "later connections attach without a prompt" does not hold across all new instances.
  The worker screencaptured, asked, touched nothing; Daniel clicked it on return. Send him a Telegram line immediately.
- **Daniel AFK rule (2026-09-26):** if he's needed and doesn't answer, pause everything (worker idle, no new reviews).
- `log show` for the app: add `AND process == "JevPaste"` — `make test` logs under the same subsystem from
  `swiftpm-testing-helper` and floods the tail.
- Daniel's idea for later (not this map): a Pi-driven way to see/approve Mac prompts from the phone — macOS Screen
  Sharing (built-in VNC) + a VNC app + Tailscale; the agent sends a Telegram screenshot, he taps through remotely.

## Suggested skills (next session)
`wayfinder` (every session), `pi-intercom` + Herdr CLI (worker 3 launch and gates), `diagnosing-bugs` (the F1 chooser
finding, via the worker), `grilling` + `domain-modeling` (Daniel's chooser decision; later the Typesafe-direct ticket),
`code-review` pattern for the GPT-6-Sol review brief, `telegram-bridge` (Daniel answers from his phone), `handoff`
(write into `docs/HANDOFF.md`, Daniel's override; hand off before ~200k).
