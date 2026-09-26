# Brief — Implement Narrowing (issue #50)

You are a fresh Pi session (`anthropic/claude-opus-5-5:high`) in worktree `~/.pi/worktrees/jevpaste/narrowing`,
branch `narrowing` (forked from `main`). This is a **production slice**: TDD, review chain, merged when done. Your
supervisor is the Pi session with intercom id **`01a0de5c-66a4-73bd-9ff8-6ee5f9f81836`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks **only through the supervisor** — every
live step where Daniel acts is an `intercom ask`, and you wait. You are the only worker; the installed app is
shared with Daniel's daily use — `make install` only when a gate reply says go.

Communication protocol:
- `intercom send 01a0de5c-66a4-73bd-9ff8-6ee5f9f81836` one line after every numbered step: `[narrowing] step N done — <fact>`.
- `intercom ask 01a0de5c-66a4-73bd-9ff8-6ee5f9f81836` (blocking) at each **GATE** and for every live action; prefix with `[narrowing]`.
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
   (`git show spike/narrowing:<path>`; the spike worktree is gone, the branch stays).
   Port the **design** and **every wording verbatim** (the section below repeats them; the FINDINGS win on any
   difference — say so). Python modules there (`cuts.py`, `run.py`, `round2/*.py`) are the reference behaviour
   for cutting, grouping, the follow-up choice and the size model; they are not to be copied line by line.
   Known misses Daniel accepted for this beta (see the #49 resolution): "Description" on a freelance
   listing gets the whole résumé; "Name" from a cover letter gets the whole letter in about half the runs. Don't tune
   for them in Swift; report them if the live runs show them.
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

## The design you port (design `r2b`: `r2` frozen at round 2's Gate A, plus the Gate A2 keep-form change, 2026-09-26)
Source: `spikes/narrowing/round2/FINDINGS.md` "Design `r2b`" (branch `spike/narrowing` @ ba32886); FINDINGS wins on any difference.

**Cutting** — character classes only, no meaning rules (round 1 `cuts.py`, round 2 `r2.py: children2`):
- Line breaks → lines. A *line piece* is a run of consecutive non-blank lines (inner blank lines kept; starts and
  ends on a non-blank line; outer spaces trimmed).
- A *token* is a maximal run of letters/digits (Python `str.isalnum` — port as Unicode alphanumerics), or any
  single other non-space character. A *token piece* is a run of consecutive tokens within one line (exact slice).
- *Characters*: every substring of a single token.
- *Edge cuts*: a one-line piece → every cut at a character inside its first/last token; a multi-line piece → four
  unit cuts (without its first token / first character / last token / last character).
- **Children of a piece P** (deduplicated by text, P itself excluded) = the *coarse* children ∪ the *fine runs*:
  - coarse: P of ≥ 2 lines → every line run + the edge cuts (grouped into *blocks* when too big: units grouped into
    blocks of b, smallest b that fits — every run of blocks + every single unit + edge cuts if they still fit);
    P of one line with ≥ 2 tokens → every token run + edge cuts (or blocks); one token → every character
    substring; one character → final, no call.
  - fine runs: every run of 1..8 consecutive tokens inside one line of P, not already among the coarse.
  - The fine runs are **grouping only** (every substring stays reachable through the coarse children — port the
    spike's reachability check as a property test). They are left out when the set would need more than 12 choice
    questions or would not fit the size budget (in the spike: only the 300-line list and the too-big copy).

**Choices per step** — at most 252 pieces + *unchanged* + *nothing fits* + *ask the user* = 255 options per choice.
Layout "cont": when the coarse set is ≤ 126 pieces, the coarse pieces are repeated in **every** choice and the fine
runs are spread over the choices in document order; otherwise all children in document order, cut into runs of
252. Every choice carries the same wording; questions in one request run in parallel and the state counts once.

**Option form** — *ids*: every piece option has a `null` description; the texts live once in
`state.excerpts` (`{"x0000": "<text>", …}`), so `state = {source_document, target_context, excerpts}`. Step 1's
`everything` option keeps its text-less description. **At later steps the unchanged option is itself the excerpt id
of `current_piece`**: its text sits in `state.excerpts` like every other piece, its description stays verbatim
"`current_piece` as it is, nothing cut away.", and local code maps that id back to *unchanged*. (Gate A2: with a
text-less keep, near-duplicate children such as `7` under `77` took its mass; keep went from 0.52 to 0.97.)
**Full-text fallback** when the size model says the state would overflow (in the spike: the three-emails résumé,
the 300-line list, the too-big copy): option descriptions carry the full excerpt text verbatim with real line breaks
(`e000`…), no `excerpts` in the state, the wording's option sentence is the full-text one (below), and the later-step
unchanged option's description is the object `{"option": "`current_piece` as it is, nothing cut away.", "text":
<current_piece>}`. Both shapes ship; one owner of the decision which one a request uses. **When a request falls
back to full text, its pieces are re-split into choices by the full-text size budget, not reused from the ids
split** (round 2 found this bug: the 300-line list reused the count-only split and Jev refused it with
`max_tokens_exceeded`). Make it a test case.

**Follow-up** — a step with several choices → one follow-up choice (same wording as the step) over *unchanged* +
every piece with p ≥ 0.01 in any of the choices + nothing fits + ask the user. If every choice picks the **same**
non-piece option (unchanged, nothing fits, ask the user), that is the step's answer and no follow-up is sent.
**Speculative fan-out** (TypeSafe's documented pattern): the follow-up request also carries the next-step question
for the top 3 carried pieces (only those whose children fit in one choice); if the follow-up picks one of them, its
next step is already answered and no call is made for it. Log honestly which happened.

**Outcome** — argmax of the deciding choice. Byte-exact check of every pick against the offered pieces at every
step. *Unchanged* ends Narrowing with the current piece as the Paste Result (the whole copy → outer line breaks
stripped); *nothing fits* → No Suitable Match with the Enter offer, at any step; *ask the user* → the Candidate
Chooser listing every option of the deciding choice with p > 0 except nothing/ask, most likely first; a piece →
the next step on that piece.

**Size model** (`cuts.py`, round 1, unchanged): estimated input tokens = 0.25 per letter, 1.0 per digit, 1.0 per
other non-space character, +12 per option, +250 per question; +4 per excerpt id in the ids form. Budgets: 92 % of
32k for state + the largest single question, 92 % of 64k for the whole request. The estimate over-counts Jev's
real `inputTokens` by ≈ 1.4× (safe side). Jev refuses over the limit with HTTP 400 `max_tokens_exceeded`.

**Measured calls and time** (round-2 `r2b` matrix, 164 pastes, paid Gateway tier from 17:18 on): 1.74 calls per paste
(1 × 57, 2 × 99, 3 × 8, 4 × 2); per paste median 1028 ms, p90 1564 ms, max 3421 ms (the 300-line list, 4 calls); per
call warm median 581 ms, p90 834 ms; cold 0.5–1.4 s. Speculative fan-out saved a call 33 times. 279 requests used
the ids form, 8 the full-text fallback. On the paid tier the Gateway returned no 429 (it did on the free tier).

## Wordings (verbatim — do not edit a character; frozen at round 2's Gate A)
Checked against round-2 `FINDINGS.md` "Every wording, verbatim" @ ba32886: identical.

**Step 1 `instructions`** (a string), ids form:
> The user copied `source_document` and pressed paste. `target_context` describes the place where the text cursor is, and what surrounds that place. One option is everything that was copied, as it is. Every other excerpt option is the id of an exact excerpt cut from `source_document`; `excerpts` gives the text of each id, character for character. Choose what will be pasted at the text cursor. If that place asks for one particular thing, choose the option that is exactly that thing, with nothing missing and nothing extra; only if no option is exactly that, choose the option that contains all of it with the least extra text. If that place does not ask for one particular thing, choose everything that was copied. If two or more different excerpts are each exactly the thing that place asks for and nothing says which one is meant, choose `ask_user` instead of one of them.

**Later steps** — `instructions` is the object `{"current_piece": <the piece, verbatim>, "question": <text>}`; the text, ids form:
> The user copied `source_document` and pressed paste. `target_context` describes the place where the text cursor is, and what surrounds that place. `current_piece` is an exact excerpt of `source_document`. One option is `current_piece` kept as it is. Every other excerpt option is the id of a smaller exact excerpt cut from `current_piece`; `excerpts` gives the text of each id, character for character. Choose what will be pasted at the text cursor. If that place asks for one particular thing, choose the option that is exactly that thing, with nothing missing and nothing extra; only if no option is exactly that, choose the option that contains all of it with the least extra text. If that place does not ask for one particular thing, choose `current_piece` as it is. If two or more different excerpts are each exactly the thing that place asks for and nothing says which one is meant, choose `ask_user` instead of one of them.

**Full-text fallback** replaces only the option sentence — step 1:
> Every other excerpt option is an exact excerpt cut from `source_document`; its description is that excerpt, character for character.

later steps:
> Every other excerpt option is a smaller exact excerpt cut from `current_piece`; its description is that excerpt, character for character.

**Option `everything`** (step 1; option id `everything`):
> Everything that was copied, as it is: all of `source_document`, nothing cut away.

**Option `keep`** (later steps):
> `current_piece` as it is, nothing cut away.

**Option `nothing_fits`**:
> That place asks for one particular thing, and no part of `source_document` is that thing.

**Option `ask_user`**:
> That place asks for one particular thing, two or more different excerpts of `source_document` are each exactly that thing, and nothing says which one is meant; the user has to pick.

Parallel choices of one step and the follow-up choice use the wording of the step they belong to. Question `type`
is `choice` everywhere; there is no `boolean`/`noul` question anywhere in the app after this slice.

Test every wording by exact string equality against the encoded request body; any change is an `ask`.

**One home for everything a later round may retune.** Daniel wants to improve Narrowing after this beta (a new
spike round with real misses and fresh held-out cells). So every wording, the option form rules, the fine-run length
(8 tokens), the layout rule (coarse ≤ 126 repeated per choice), the 12-question cap, the carry threshold (p ≥ 0.01)
and the speculative fan-out width (3) live in **one** Narrowing policy value in Core (or one file per concern next to
it), named, documented, and injected, not scattered through the loop and the gateway. A later round then changes that
value and its tests, not the architecture. Say at Gate A where it lives.

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

Out of scope: the place choice (measured in round 2; Daniel said no), splitting a too-big copy into windows, the history UI look, the provider
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
