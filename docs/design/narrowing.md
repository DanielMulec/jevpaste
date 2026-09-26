# Narrowing — design

Slice [#50](https://github.com/DanielMulec/jevpaste/issues/50); contract [#47](https://github.com/DanielMulec/jevpaste/issues/47#issuecomment-5845599979); proof: design `r2b`, `spikes/narrowing/round2/FINDINGS.md` on
`spike/narrowing` @ ba32886 (FINDINGS win on any difference). Glossary: **Narrowing**, **Candidate** (`CONTEXT.md`).

## Cutting (`SmartPasteCore/Narrowing/PieceCutting.swift`, `PieceChildren.swift`) — character classes only
A piece is a `Substring` of the Active Item's text: a `String.Index` range into it, so every piece, child and pick is a
byte-exact slice. Units: lines (runs of non-blank lines, outer whitespace trimmed; `Character.isNewline`, CRLF one
break); tokens (maximal run of letters/numbers, else one non-whitespace `Character`); characters. **The one intended
difference from the spike's code:** Swift `Character`s (grapheme clusters) replace Python's code points, so a cut never
splits "é" written as e + ◌́ or an emoji (the size estimate still counts scalars, like Python).
Children of P, deduplicated by UTF-8 bytes (never `String` equality), P excluded = coarse ∪ fine runs, as `r2b`:
coarse = line runs + 4 edge cuts (≥ 2 lines) · token runs + character edge cuts (1 line, ≥ 2 tokens) · every
substring (1 token) · none (1 character); blocks of b units (smallest b that fits) when too big. Fine runs = every run
of 1–8 tokens inside one line, dropped when > 12 questions or over the size budget. No meaning rule exists anywhere.
Also excluded: what keeping P pastes — at step 1 the copy without outer line breaks (live run 2026-09-26, Daniel: yes;
the spike's copies had no trailing line break, so it never offered the keep twice; no-op on every recorded cell).

## Grouping, option form, size model (`Narrowing/StepPlanner.swift`, `StepBudget.swift`, `RequestAssembly.swift`)
Core plans every request, because every decision that needs Jev's limits is Core's (blocks, fine-run drop, choice
split, ids vs full text, speculative fit). Layout "cont" (coarse ≤ 126 → repeated in every choice, fine runs spread in
document order; else all in document order), 252 pieces + keep + `nothing_fits` + `ask_user` per choice. Form: ids
(`x0000…` shared per request, `null` descriptions, later-step keep = the excerpt id of `current_piece`); when the
request estimate overflows → full text (`e000…`, full excerpt text with real line breaks, keep =
`{"option", "text"}`), **re-split by the full-text budget**. Size model = `cuts.py` unchanged, estimated over the
one JSON rendering (`Narrowing/OrderedJSON.swift`, ordered, compact) that the Gateway also sends. Jev's limits
(TypeSafe Models page: 255 options per choice, 32k tokens state + largest question, 64k per request; 92 % used) live
in the size model — one owner; the Gateway keeps no cap and no 255-character cut. Planning (main actor) stays linear:
one rolling-hash pass per piece length for document order, children once per step; `make planning-time` (release)
holds ≤ 20 ms per step on the recorded pastes, ≤ 100 ms on N03, ≤ 250 ms on a 3000-line copy.

## One home for what a later round retunes — `NarrowingPolicy` (Core), injected through `PasteAttemptRules`
`NarrowingPolicy.r2b`: `wordings` (`NarrowingWordings.swift`: step-1/later instructions in both forms and their fill
variants, `everything`, `keep`, `nothing_fits`, `ask_user`), option ids, fine-run length 8, coarse-repeat limit 126, 12
questions, carry p ≥ 0.01, fan-out width 3, `sizeModel`. No number or text elsewhere.

## Step loop (`Narrowing/Narrowing.swift`, a pure value; coordinator `PasteAttemptCoordinator+Narrowing.swift`)
`Narrowing.start() / receive(answers) -> NarrowingAction` = `.send(NarrowingRequest)` · `.pasteResult(String)` ·
`.nothingFits` · `.askUser([Candidate])` · `.invalidPick` · `.nothingToPaste`; the coordinator owns phases, clocks.
- Step 1 always asks (even a copy with no pieces: `everything` / `nothing_fits` / `ask_user`); a later piece with no
  children (one character) is final without a call. A copy with no visible character → plain No Suitable Match, no
  call (as today). Both deviate from the spike code on purpose (Gate A: a no-call shortcut at step 1 would decide).
- One choice → its argmax decides. Several → if every choice picks the same keep/nothing/ask, that is the answer;
  else one follow-up choice (same wording) over keep + every piece with p ≥ 0.01 in any choice (document order) +
  nothing + ask, carrying the next-step question of the top 3 carried pieces whose children fit one choice; a
  speculative answer is used instead of a call when its piece is picked. Follow-up forms tried: ids+spec, full+spec,
  ids, full; the first that fits is sent (else the last).
- Every pick passes `ClipboardItem.acceptsPasteResult(_:offeredAmong:)` (UTF-8 bytes, offered, verbatim in the item;
  plus strictly inside the current piece) → else `failed(.invalidResult)`, no retry. Keep → the piece (the whole copy
  with outer line breaks stripped); nothing → the Enter offer at any step; ask → the chooser fill.
- **Chooser fill** (`ChooserFill.swift`; F1, Daniel 2026-09-26: Jev gives the non-ask weight to the first exact
  candidate only; the second address got 0 in 16/16 runs): the deciding choice asked again (same ids, form, order;
  `*Fill*` wording = the step's minus its `ask_user` sentence) without `ask_user` and every piece with an occurrence
  overlapping a row's (UTF-8, in the current piece); each checked pick is the next row; keep/nothing → chooser with
  the rows in order (no row yet: keep → the paste, nothing → the offer). No cap. Clock, 429 past it, `.failed` or
  `.tooLarge` mid-fill → chooser with the rows found; none → the step's outcome.
- Clock: 5 s from the Bound Target over every step, fill call and 429 wait (`JevConsultation.deadline`); phase
  `deciding` spans them, so a click cancels between them; chooser and offer off the clock; the 150 ms indicator once.

## Seam — `DecisionService.evaluate(_ NarrowingRequest, reply: (NarrowingReply) -> Void)`
`NarrowingRequest { sourceDocument, targetContext, excerpts: [id, text], questions: [ChoiceQuestion { id, instructions:
.text | .onPiece(currentPiece, question), options: [id, .text | .excerpt(null) | .keptPiece(option, text)] }] }`.
`NarrowingReply = .answered([questionID: ChoiceAnswer { choice, probabilities }]) | .rateLimited(retryAfter:) |
.tooLarge | .failed`. The Gateway wraps Core's JSON of state + questions (keys in the spike's order, which Jev reads)
with `model`, maps 200/429/400-`max_tokens_exceeded` (top-level `error.message`/`param.error`, or any
`providerAttempts[].error` whose JSON `error_type` is it)/other, and logs status, questions, options, bytes, latency.

## Outcome and log line
`.tooLarge` → `PasteAttemptFailure.tooLongForSmartPaste`: "Too long for Smart Paste — ⌘V pastes it whole", log key
`failed.tooLongForSmartPaste`. Log line: `via=narrowing steps=<n> calls=<m> p=<deciding p> questions=<per step>`,
per step `<questions>`, `+f<spec>` after a follow-up, `s` when answered speculatively (N03: `2+f0,2+f2,s`); `calls`
counts every POST (429 retries too); ` stepP=<chosen p per step>`; after an ask ` fill=<n> fillEnd=<why>`; then
` full=<k>` for k full-text requests and ` offer=dismissed|timedOut`. Enter after No Suitable Match:
`via=directPaste reason=enterAfterNoMatch p=<deciding p>`.

## Removed
Core `Candidates/*`, `CandidateExtraction`, `Decision`, `+Decision`, `DirectPasteRule` (→ `OuterLineBreaks`); the
Gateway's three questions, `none_of_these`, 254 cap, 255-character cut, `tooManyCandidates`; and their tests.

## Tests per scope item
1 `PieceCuttingTests`, `PieceChildrenTests` (byte-exact slices, CRLF, graphemes, dedupe, parent excluded, blocks,
fine drop), `NarrowingReachabilityTests` (spike `self_check` on its samples + every target of the 82 cells that fit).
2 `NarrowingRequestEncodingTests` (every wording by exact string equality in the body, full text verbatim > 255
characters, key order), `NarrowingReplyTests` (probabilities, unknown id, 429, both 400 forms → tooLarge, other 400).
3 `PasteAttemptNarrowing(Clock)Tests` (clock over steps and 429, cancel between steps, invalid pick, one-character
piece final, no call for whitespace), `NoSuitableMatchOfferTests`, `PasteAttempt{Chooser,ChooserFill}Tests`.
4 `StepPlannerTests` (layout, forms, size model, N03 fallback re-split 151 + 151), `NarrowingStepTests` (agreement,
carry, speculation), `NarrowingChooserFillTests`, **`NarrowingReplayTests`**: 14 recorded `r2b` pastes through Core and
the Gateway encoder, every request byte-identical, every outcome identical (ending in `ask_user`: the first fill).
5–6 `OutcomeMessageTests`, `NarrowingLogLineTests`. Kept, adapted: the older Core and App tests. Live: brief step 4.
