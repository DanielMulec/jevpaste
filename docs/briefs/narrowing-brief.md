# Brief — Implement Narrowing (issue #50)

> **DRAFT — not launched.** Every block marked `⟦PORT⟧` is filled verbatim from `spikes/narrowing/round2/FINDINGS.md`
> (branch `spike/narrowing`) once [Spike: does choice-only Narrowing pass the any-field matrix?](https://github.com/DanielMulec/jevpaste/issues/49)
> reports a pass. The supervisor removes this banner at launch.

You are a fresh Pi session (`anthropic/claude-opus-5-5:high`) in worktree `~/.pi/worktrees/jevpaste/narrowing`,
branch `narrowing` (forked from `main`). This is a **production slice**: TDD, review chain, merged when done. Your
supervisor is the Pi session with intercom id **`⟦SUPERVISOR-ID⟧`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks **only through the supervisor** — every
live step where Daniel acts is an `intercom ask`, and you wait. You are the only worker; the installed app is
shared with Daniel's daily use — `make install` only when a gate reply says go.

Communication protocol:
- `intercom send ⟦SUPERVISOR-ID⟧` one line after every numbered step: `[narrowing] step N done — <fact>`.
- `intercom ask ⟦SUPERVISOR-ID⟧` (blocking) at each **GATE** and for every live action; prefix with `[narrowing]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. Never log or print item
  text, field labels or window titles; refer only to `JEVPASTE-…` synthetic payloads.

## Read first (in this order)
1. `gh issue view 50` — your ticket (assigned to Daniel; that is the claim, leave it). Its body is the scope.
2. The contract, verbatim: `gh api repos/DanielMulec/jevpaste/issues/comments/5845599979 -q .body`
   (resolution of [Decide the extraction engine for any-field Smart Paste](https://github.com/DanielMulec/jevpaste/issues/47)).
   The **12-item inventory** there says what goes and what stays; the **Jev-first rule** in the map Notes
   (`gh issue view 1`) is absolute: no yes/no question, no local rule that decides meaning, no field or place
   vocabulary in any wording, no app names in behaviour. A new local gate, cap or classifier is not yours to add.
3. The proof you port: `spikes/narrowing/round2/FINDINGS.md` and the round-1 `spikes/narrowing/FINDINGS.md`
   (`git show spike/narrowing:<path>`, or read the worktree `~/.pi/worktrees/jevpaste/narrowing-spike` read-only).
   Port the **design** and **every wording verbatim** (the section below repeats them; the FINDINGS win on any
   difference — say so). Python modules there (`cuts.py`, `run.py`, `round2/*.py`) are the reference behaviour
   for cutting, grouping, the follow-up choice and the size model; they are not to be copied line by line.
4. `CONTEXT.md` (**Narrowing**, **Candidate**, **Candidate Chooser**, **No Suitable Match**, **Direct Paste**,
   **Paste Result**, **Embedded Value**), `docs/quality-gate.md`, `docs/design/paste-attempt-state-machine.md`,
   `docs/design/jev-gateway.md`, `docs/design/candidate-derivation.md`, `docs/design/direct-paste.md`,
   `docs/design/free-text-target.md`, `docs/design/candidate-chooser.md`, `docs/design/no-suitable-match-offer.md`,
   `docs/design/cursor-context.md`, `Makefile`.
5. Code you will touch (read it all before Gate A):
   - `Sources/SmartPasteCore/Values/Decision.swift`, `Seams/DecisionService.swift` — today one request = one
     batched call with three questions (`paste` choice, `contains_value`, `free_text`). Becomes one **Narrowing
     step**: the whole copy and the Target Context, the current piece (the whole copy at step 1), the pieces
     offered, and Jev's answer as a typed choice among *piece unchanged / one of the pieces / nothing fits / ask
     the user* with the probability of every option (the Candidate Chooser lists the ones Jev gave weight to,
     most likely first). A new reply for "Jev refused the size" (see scope 5), distinct from `failed`.
   - `Seams/CandidateExtraction.swift`, `Candidates/*` (`CandidateCap`, `CandidateType`, `HeadingLikeLine`,
     `LabelledLine`, `StructuralCandidateExtraction`, `StructuralExcerpts`, `SourceLines`, `Excerpt`) — the
     structural derivation, the type detection, the same-type rule and the 254 cap go. What replaces them is
     **cutting**: character classes only, every piece a byte-exact slice, no piece ever unreachable.
   - `DirectPaste/DirectPasteRule.swift` — the single-line rule goes; `withoutOuterLineBreaks` stays (every
     whole-copy paste: Jev keeping the whole copy at step 1, and Enter after No Suitable Match).
   - `PasteAttempt/PasteAttemptCoordinator.swift` (`proceed`, `askJev`), `+Decision.swift` (the whole file:
     `containsValueThreshold`, `freeTextThreshold`, `decided`, `pasteWholeItem`, the same-type branch), `+Delivery.swift`,
     `+NoSuitableMatchOffer.swift`, `PasteAttemptPhase.swift`, `PasteResultValidation.swift`, `Values/SmartPastePath.swift`,
     `Values/PasteAttemptOutcome.swift`.
   - `Sources/JevGateway/EvaluateRequestBody.swift` (the three questions, `maximumOptionDescriptionLength`, the
     field-vocabulary wordings — all go), `EvaluateResponse.swift`, `JevGatewayFailure.swift`, `JevGatewayDecisionService.swift`.
   - `Sources/JevPasteApp/Indicator/OutcomeMessage.swift`, `SmartPastePath+LogFragment.swift`, `IndicatorPresenter.swift`
     (log line), `Chooser/*` (the list Jev weighted), `AdapterProbe.swift` if it references removed types.
   - Tests that describe removed behaviour go with it: `FreeTextTargetTests`, `FreeTextTargetGatewayTests`,
     `PasteAttemptDirectPasteTests`, `CandidateSameTypeTests`, `CandidateCapTests`, `CandidateDerivationTests`,
     `CandidateVerbatimTests`, parts of `JevGatewayRequestTests` / `PasteAttemptDecisionTests`. Keep what still
     holds (byte-exact validation, 5 s clock, 429 retry, the Enter offer, Wake Wait) and say which.
6. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
7. Tools for the live proof: Chrome DevTools MCP server `chrome-devtools` (lazy: `mcp({connect:"chrome-devtools"})`
   first; `list_pages`, `new_page`, `select_page`, `click`, `fill`, `evaluate_script`, `close_page` — **re-list and
   verify the URL immediately before closing anything**; it drives Daniel's real Chrome; only your own tabs;
   `hasFocus()` is emulated — gate every synthetic step on the frontmost app being Chrome). Herdr CLI for terminal
   steps (`herdr tab create`, `herdr pane get <id>` focused=true + frontmost-app check before every synthetic
   step, `herdr pane send-keys <pane> C-c`, `herdr pane read <pane> --source visible`). The installed app started
   with `open ~/Applications/JevPaste.app --args --accept-signal-trigger` accepts `kill -USR1 <pid>` as ⌘⇧V
   (`Sources/JevPasteApp/Launch/AcceptanceTrigger.swift`) — **signal by pid only, never `pkill -USR1`**. Launch the
   app via `open … --args`, never from your shell. Logs: `log show --predicate 'subsystem == "jevpaste"' --info
   --last 2m` (see existing acceptance logs for the predicate; `JevGateway` logs at INFO).
8. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).
   If the link fails with an undefined-symbol mangling mismatch after adding files, `swift package clean` first.

## The design you port  ⟦PORT from round-2 FINDINGS: "Design (as run)" + "Size model"⟧
- Cutting (character classes only): ⟦PORT⟧
- Children of a piece, grouping, flattening, blocks when too big for one request: ⟦PORT⟧
- Several choice questions in one request, the follow-up choice among their winners, when the follow-up is
  skipped: ⟦PORT⟧
- Outcome = argmax of the deciding choice; the chooser list; whole-copy pastes strip outer line breaks: ⟦PORT⟧
- Size model (token estimate per character class, per option, per question; the two budgets): ⟦PORT⟧
- Expected calls per paste and the measured latency: ⟦PORT⟧

## Wordings (verbatim — do not edit a character)  ⟦PORT from round-2 FINDINGS: "Wordings (verbatim)"⟧
- Step-1 instructions: ⟦PORT⟧
- Later-step instructions and the `current_piece` field: ⟦PORT⟧
- "everything that was copied" (step 1) / "current piece unchanged" (later steps): ⟦PORT⟧
- "nothing fits": ⟦PORT⟧
- "ask the user": ⟦PORT⟧
- Parallel choices and the follow-up: ⟦PORT⟧

Test every wording by exact string equality against the request body; any change is an `ask`.

## Scope
1. **Cutting** (Core, pure): the port of the spike's cutting — pieces are byte-exact slices of the Active Item
   (`String.Index` ranges or UTF-8 offsets, your Gate A call), children of a piece as in the design, deduplicated
   by text, the parent excluded. **Property test:** every substring that starts and ends on a non-space character
   is reachable by some path of choices (port the spike's `self_check`; run it over the fixture texts of both
   rounds). No meaning rules: no heading, label, type or vocabulary anywhere.
2. **Narrowing step loop** (Core): from the whole Active Item, each step asks one request (one or several choice
   questions), checks Jev's pick byte-exact **at every step** (`PasteResultValidation` / `accepts`; a pick that
   is not an offered piece → `failed(.invalidResult)`, never a silent retry), then: **keep** → deliver that piece
   (the whole copy with outer line breaks stripped); **nothing fits** → the existing No Suitable Match offer
   (`offerDirectPaste`), at any step; **ask the user** → the Candidate Chooser with the options Jev gave weight to,
   most likely first (the chooser's pick is checked byte-exact too); **a piece** → next step with that piece; a
   single character → final, no call. The **5 s clock runs from the Bound Target over every step and every 429
   wait** (`JevConsultation.deadline` as today); the chooser and the offer stay off the clock; the ~150 ms
   indicator is unchanged; cancel (click) works between steps. The Pre-checks stay in front. No Direct Paste
   branch remains in `proceed`; ordinary ⌘V is untouched.
3. **Gateway** (JevGateway): one `POST /v1/evaluate` per step with N choice questions (document order, the
   unchanged option in each), option descriptions **in full, verbatim, with real line breaks** (the 255-character
   cut is gone — it was never Jev's limit), 255 options per question at most, state = `source_document` +
   the production `target_context` shape at every step, `instructions` as in the wordings block. Response: the
   pick and the probability of every option per question. HTTP 429 → `rateLimited` as today. **HTTP 400 whose
   body carries `max_tokens_exceeded`** (directly, or inside the Gateway's fallback form `typesafe returned
   status 400` with `providerAttempts[].error`) → the new "too large" reply. Other statuses → `failed`.
   Logs: status, question and option counts, request bytes, latency — never text.
4. **Grouping and the size model** (where it lives is your Gate A proposal — Core owns the pieces and the loop,
   the Gateway owns Jev's limits; keep one owner per fact): split a step's pieces across questions by the
   255-option limit and the token budget; a follow-up choice among the winners; blocks when even that is too big.
5. **Too long for Smart Paste:** when Jev refuses the size (scope 3), the outcome is a visible failure with the
   text exactly `Too long for Smart Paste — ⌘V pastes it whole` (a new `PasteAttemptFailure` case, its
   `OutcomeMessage` and log key). No local size count decides anything; the request is always sent.
6. **Diagnostics:** `SmartPastePath` loses `freeTextTarget` and `directPaste`-by-rule; the log line becomes
   `via=narrowing steps=<n> calls=<m> p=<p of the deciding option>` (+ `offer=` as today; Enter after No Suitable
   Match stays `via=directPaste reason=enterAfterNoMatch`). Numbers and enums only.
7. **Docs:** `docs/design/narrowing.md` (≤ 90 lines: cutting, grouping, the step loop, the byte-exact rule, the
   size model, the wordings' home, the log line, the test list, the live-run plan in plain words);
   `paste-attempt-state-machine.md` (the loop, where the clock runs), `jev-gateway.md` (N questions, full
   descriptions, the 400 mapping), `candidate-derivation.md` / `direct-paste.md` / `free-text-target.md` /
   `candidate-chooser.md` (mark superseded or fold, one line each pointing at `narrowing.md`). `CONTEXT.md` only
   if the implementation proves a wording wrong (say so; Daniel decides names).

Out of scope: the place choice (measured in round 2; ships only on Daniel's word — if that word came, the
supervisor added a section below), splitting a too-big copy into windows, the history UI look, the provider
switch to Typesafe direct, any new gate, cap or classifier.

## Steps
1. Read everything above. `docs/design/narrowing.md` with your proposals. **GATE A** (`ask`): the doc path; the
   `DecisionRequest`/`Decision` (or renamed) shapes; where grouping and the size model live; the cutting
   representation; the follow-up rule; the log line; the list of files deleted; the test list per scope item.
   The supervisor checks the wordings against the FINDINGS character for character.
2. Implement TDD, small commits (`make check` green before each), in this order: cutting + reachability property
   → gateway request/response/400 mapping → the step loop → grouping/follow-up → outcome text and log line →
   removals and doc folds. Push after each gate.
3. **GATE B** (`ask`): the `make test` summary line, `wc -l` of every file you touched or added, and a one-line
   proof per scope item (test names). The supervisor reads the Core + Gateway diff before approving.
4. **Live proof** (gated; `ask` once for `make install`, then run the automated part; Daniel's block last).
   **Payload rule:** pure values, one per line, the `JEVPASTE-…` marker on its own line; committed logs carry
   counts, digests, statuses and `via=` lines — **no literal text, no window titles, no `/Users/<name>` paths**.
   Restore the clipboard vault **before** relaunching the app (Launch Adoption would adopt the fixture).
   Automated (you, no Daniel):
   (a) Chrome `data:` form with labelled fields (`Ort`, `E-Mail`, `Telefon`, `Straße`, `Hausnummer`, a large
       `Kommentar` textarea): the single-line copy `Mira Holzner, Prankergasse 77, 8020 Graz` into `Ort` → `Graz`;
       a four-line signature into `E-Mail` → the address alone; the same copy into the textarea → the whole copy,
       outer line breaks stripped; a copy holding nothing for `Telefon` → No Suitable Match with the Enter offer,
       then let it time out (nothing inserted).
   (b) A Herdr shell prompt: a lone URL → the whole URL at the prompt, not executed, then `C-c`.
   (c) A copy with more than 253 pieces (the spike's list) into a labelled field → the value; log shows the
       question count per step.
   (d) A copy too big for one call → `Too long for Smart Paste — ⌘V pastes it whole`, nothing inserted, log key.
   (e) Timing: `via=narrowing` lines with steps/calls; every paste under 5 s cold.
   Daniel's block (one `ask`, plain words, say *why* each step exists): (f) two emails of one person into an
   `E-Mail` field → the Candidate Chooser opens with the two, he picks one → it lands; (g) WhatsApp chat box and
   the ChatGPT composer with a three-line copy → the whole copy. Tell him to move the mouse to the top edge to
   see the indicator; the log is the proof.
   Every helper output backing a claim goes into `docs/acceptance/run-<date>-narrowing.log` at run time.
5. Push. Report comment on issue #50: what was built, the design as built, wordings (link, not paste), test
   count, live evidence with `via=narrowing` values per target, timing, commits, merge touchpoints, open
   questions. **GATE C**: `ask` with the comment URL, then end your turn. Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency, no async in Core (reply-closure ports).
  ≤ 400 lines per file including tests, split by concern. Descriptive names from the glossary. No new
  dependencies without `ask`. Commit small on `narrowing`. Bare `swift test` does not link — use `make test`.
  Do not merge.
- Fakes model visible state and fire callbacks only when the seam's contract says so (two reviews found loose
  fakes before). Capture the instant a clock starts from and derive timers from it.
- Reviewers read the committed log, not your session: every digest/count backing a claim goes into the log.
- A wording, a threshold or a rule you want to change after Gate A is an `ask`, never a quiet edit.

## Report format
`[narrowing] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
