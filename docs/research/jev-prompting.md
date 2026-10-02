# What Typesafe says about asking Jev, and where jevpaste deviates

- **Date:** 2026-10-02. Brief: `docs/briefs/jev-prompting-research-brief.md`. Research only, no decision. Feeds the
  deviation discussion with Daniel and the next Narrowing round ([#52](https://github.com/DanielMulec/jevpaste/issues/52)).
- **Labels:** `primary-doc` (a Typesafe source says or shows it; Vercel's docs for Gateway behaviour) · `measured`
  (jevpaste's own recorded data; file and branch named) · `inferred` (my reasoning) · `unknown` (looked for, not found).
- **Baseline read:** `NarrowingWordings.swift`, `NarrowingPolicy.swift`, `NarrowingRequest.swift`, `RequestAssembly.swift`,
  `StepPlanner.swift`, `Narrowing.swift`, `FollowUp.swift`, `ChooserFill.swift`, `TargetContextReader.swift`,
  `JevEndpoint.swift`, `JevConnectionTest.swift`, `docs/design/narrowing.md`, `docs/design/jev-gateway.md`, `CONTEXT.md`,
  issue #52, and on `spike/narrowing` @ ba32886: `spikes/narrowing/round2/FINDINGS.md` (M-R2), `…/round2/results/explore.md`
  (M-EXPL), `spikes/narrowing/FINDINGS.md` (M-R1), `spikes/{abstention,context,granularity}/FINDINGS.md` (M-ABST, M-CTX, M-GRAN).
- **New measured data without new calls:** I re-read every recorded response in `spikes/narrowing/results/raw.jsonl` and
  `spikes/narrowing/round2/results/raw.jsonl` (710 Gateway calls with status 200, 1,752 Choice answers; M-RAW). Plus 4 tiny
  probes (§6).
- The sister project's research file was used only as a map to sources; every claim below was read at its source.

## 1. TL;DR

1. **Typesafe's core advice is "narrow, atomic, one snap judgment per question; code composes"** (DOC-PRIM, DOC-HOW, all
   five talks). jevpaste asks one 150-word, 8-sentence Choice that holds three conditional branches plus an ask rule
   (R9). That is the largest deviation by the letter of the docs. The skill file softens it ("a bounded action selection
   or contextual interpretation is valid", REPO-SKILL), and our wording history (V0 → V5) is measured, not guessed.
2. **Typesafe documents the shape of Narrowing.** "With more candidates than [255], narrow in two stages: pick the
   section first, then the span inside it" (CB-PREPARSED); "pick a window of lines, and a second ranks the lines inside
   it" (CB-FIND); chunk, rank each, shortlist the winners (CB-SKILL). The multi-step, chunk-and-follow-up design follows.
3. **Overlap is the documented weak spot.** Allie Laabs (Typesafe devrel): Choice "works best when there's going to be
   one dominant answer and the choices don't have a huge amount of overlap" (TALK-LC 0:13:00); the same point in TALK-TD
   0:17:48 and 0:23:56 ("if they aren't mutually exclusive, you should be breaking that further into more primitives").
   Our options are nested excerpts of one text. Our misses (C03, C04, R10, B06) are all part-against-container
   judgements (`inferred`).
4. **Greedy steps cannot recover.** Typesafe's hierarchy cookbook: greedy "One early mistake cannot be recovered"; beam
   K=3 fixed 2 of 4 leaves (CB-HIER). Narrowing only ever goes smaller, so C03's step-1 pick of one line (0.39) could
   never get back to the two-line paragraph (`inferred`). The cheapest test: a beam over steps, or summing probability
   over nested containers in code, as CB-CLSCONF does when it reports the broader class.
5. **Two equal candidates collapse onto the first, and Typesafe's docs don't predict it.** The skill file says
   "several acceptable alternatives can also spread probability" (REPO-SKILL). We measured the opposite: 16/16 (F1),
   the abstention spike, and probe P1 (0.97 / 0.03). Typesafe's documented tool for "several may apply" is one Noul per
   label (REPO-SKILL; DOC-JAG #8). That is the obvious alternative to the chooser fill's re-asks.
6. **Probability order is not defined, and it depends on the route.** `probabilities` is a map (DOC-API). Through the
   Typesafe upstream the order changes between identical calls (same in only 29 of 491 identical repeats). Through the
   Gateway's DigitalOcean upstream it is alphabetical by option id (212/212) (M-RAW, P1–P4). `FollowUp.swift`'s tie
   order is therefore arbitrary. It only decides which pieces are speculated, and a cut at 252 carried pieces that has
   never happened.
7. **The Gateway route is not pinned to one model, and it is not even one upstream.** `typesafe-ai/jev` reports no
   version. It is served by `typesafe-ai` or `digitalocean`. On identical requests the DigitalOcean upstream moved
   probabilities by a median of 0.15 (max 0.67) and flipped the choice in 22/127 pairs. Typesafe-only pairs: median 0.02,
   13/491 (M-RAW). C04's one miss in the `r2b` matrix had its deciding call on DigitalOcean (`inferred` link, n=1).
   Vercel documents `providerOptions.gateway.only: ["typesafe-ai"]` (VERCEL-EVAL).
8. **No newer model.** As of 2026-10-02: `jev-1.13.0` only, `jev-latest` and `jev-preview` both point to it, and the
   jaggedness page was still "Last reviewed 2026-09-17" (DOC-MODELS, DOC-JAG). Diogo: no long-term-support promise yet;
   "we might temporarily LTS … Jev 1.13.0" (TALK-LS 0:50:08).
9. **The whole copy at every step goes against "only the context the question needs"** (DOC-JAG #5, DOC-HOW). Our
   measured reason holds for step 1 (dropping the source gave confident wrong answers, M-CTX, M-GRAN). At later steps
   it is untested.
10. **What we follow:** backticked state paths, object-valued instructions for code-supplied data, ids with `null`
    descriptions and texts in the state, none-of-the-above options, speculative fan-out, select-don't-generate, and all
    wordings and tunables in one place. Typesafe's explicit tuning rules ("thresholds per question on your data"; "a
    reworded question is a new instrument") match how `NarrowingPolicy` is treated.

## 2. Sources

All retrieved 2026-10-02. Docs pages as `docs.typesafe.ai/<path>.md` plus `llms-full.txt`. Talks were read as YouTube
auto-captions (English), not audio. Timestamps are h:mm:ss, and caption errors are possible.

| Key | Source |
|---|---|
| DOC-PRIM | docs.typesafe.ai/primitives |
| DOC-CHOICE | docs.typesafe.ai/primitives/choice |
| DOC-NOUL | docs.typesafe.ai/primitives/noul |
| DOC-SCORE | docs.typesafe.ai/primitives/score |
| DOC-STATE | docs.typesafe.ai/concepts/state |
| DOC-HOW | docs.typesafe.ai/concepts/how-to-build-with-system-one |
| DOC-JAG | docs.typesafe.ai/model-jaggedness/jev-1.13 ("Last reviewed 2026-09-17"); numbered failure modes #1–#9 |
| DOC-MODELS | docs.typesafe.ai/models |
| DOC-CONF | docs.typesafe.ai/confidence |
| DOC-API | docs.typesafe.ai/api |
| DOC-FAN | docs.typesafe.ai/patterns/fan-out |
| DOC-AGENT | docs.typesafe.ai/agent-skill |
| CB-FIND | docs.typesafe.ai/cookbooks/semantic_find (line-by-line search; `jev-1.12`) |
| CB-AUTOFMT | docs.typesafe.ai/cookbooks/autoformat (structure recovery) |
| CB-SKILL | docs.typesafe.ai/cookbooks/skill_suggestion (progressive disclosure; `jev-1.12`) |
| CB-PREPARSED | docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook (regex finds spans, Choice picks; `jev-1.12`) |
| CB-DATE | docs.typesafe.ai/cookbooks/date_extraction_cookbook |
| CB-HIER | docs.typesafe.ai/cookbooks/hierarchical_classification (greedy vs beam; `jev-1.12`) |
| CB-CLSCONF | docs.typesafe.ai/cookbooks/classification_using_confidence |
| CB-CCHOICE | docs.typesafe.ai/cookbooks/consistency_choice_cookbook (15 repeats, `jev-1.13.0`) |
| CB-RAG | docs.typesafe.ai/cookbooks/classifying_rag_passages |
| REPO-SKILL | github.com/typesafe-ai/skills `skills/typesafe-ai/SKILL.md` (last commit 2026-09-12) |
| REPO-WFE | github.com/typesafe-ai/WorkflowEvals (Typesafe's own production questions; practice, not advice) |
| SDK-CL | docs.typesafe.ai/sdk/python/changelog (v0.7.2, 2026-09-26), /sdk/javascript/changelog (v0.6.0) |
| BLOG | typesafe.ai/blog/introducing-system-one-models-and-jev (Diogo Almeida, 2026-09-15) |
| TALK-LS | Latent Space × Diogo Almeida, youtube `cFx9Z3ZXca0` (captions) |
| TALK-LC | "How To Build A Harness With Jev", LangChain × TypeSafe with Allie Laabs, `HHUsHkYhkcM`, 2026-09-22 (captions) |
| TALK-TD | ThursdAI with Allie Laabs, `QkPnAoHBXwo`, 2026-09-18 (captions) |
| TALK-AIE | Diogo Almeida at AI Engineer, `cJ0EOzey--o`, 2026-07-31, pre-launch (captions) |
| TALK-CR | CodeRabbit with Allie Laabs, `j8RO-IOKtvM` (captions) |
| VERCEL-EVAL | vercel.com/docs/ai-gateway/modalities/evaluation (provider options) |
| VERCEL-CAT | `GET ai-gateway.vercel.sh/v1/models` and `…/v1/models/typesafe-ai/jev/endpoints` (live) |
| M-RAW | my re-analysis of both narrowing `raw.jsonl` files on `spike/narrowing` @ ba32886 (no new calls) |
| P1–P4 | my probes, §6 |

**Talks, what they hold for wording:** TALK-LC and TALK-TD have the overlap remark (TL;DR 3), "almost always … the
question is actually like a compound question" (TALK-TD 0:24:28), confidence as "a single dominant answer" measure
(TALK-LC 0:40:14), keeping state lean (TALK-LC 0:44:47, the Doom demo), and putting all wordings in one place
(TALK-LC 0:28:05). TALK-AIE predates launch and has no question-design content. TALK-CR is about where to use Jev
("smart if statement") and speculative prompting.

## 3. Deviation register

Verdicts: `follows` · `deviates` · `partly` · `no guidance`. "TS" = what Typesafe says. Evidence: TS side is `primary-doc`
unless marked; our side is `measured` when a spike number backs it. Costs are `inferred` unless marked. Known misses:
**C03** (availability → one line), **C04** (Name → whole letter, about half of the runs), **R10** (Description → whole
résumé), **B06** (biography → nothing fits), **TWO-ADDR** (two exact addresses, no ask, live beta).

### 3a. Choice and options

| # | jevpaste does (file) | TS says (source) | Verdict | Our recorded reason | Evidence | May cost us (`inferred`) | Candidate for #52 (not run) |
|---|---|---|---|---|---|---|---|
| R1 | Choice only; no Noul, no Score (`NarrowingRequest.swift`; `CONTEXT.md` "Narrowing") | Choice for "one of a fixed set"; Noul "whether"; "A Choice … settles *which* … each Noul is absolute and can be low for all of them" (DOC-JAG #8); CB-SKILL and CB-FIND pair a Choice with Nouls | partly | `CONTEXT.md`: "Every step is a choice; no yes/no question and no local rule decides"; #47; #52 "Jev-first rule unchanged (choices, no gates)" | TS primary-doc · ours: design rule, and measured that an in-Choice `none_of_these` separated no-match 20/20 vs 0/40 (M-ABST) | Nothing on traps (16/16, M-R2). The "whether" signal for B06/R10 has to compete with nested pieces inside one distribution | A Noul *beside* the step (not a gate), logged only, to see whether it separates B06/R10 offline |
| R2 | Up to 252 overlapping, nested excerpts per Choice (`StepPlanner.swift`, `NarrowingPolicy.r2b`) | "give the model the full list … rather than a shortlist", up to 255 (DOC-CHOICE). Choice "works best when … the choices don't have a huge amount of overlap" (TALK-LC 0:13:00; TALK-TD 0:23:56: "if they aren't mutually exclusive, you should be breaking that further into more primitives") | partly | Reachability: the expected excerpt is on offer at step 1 in 55/56 positives (M-R2 D1); 255 overlapping candidates 7/7, mean top-1 0.997 (M-GRAN) | TS primary-doc (talks) · ours measured (easy fields) | Mass splits across a value and its containers, so the part-against-whole cells sit at 0.3–0.45 (C03, C04, R10, B06; M-R2 "Jev is split, not wrong-and-sure") | Offline on M-RAW: sum each step's mass over nested containers (CB-CLSCONF reports the broader class when unsure); then a live A/B |
| R3 | Option = excerpt id `x0000`, `null` description, text in `state.excerpts`; full-text fallback (`RequestAssembly.swift`) | CB-FIND: line ids as options, "`None` because the document already contains the text for each ID", ids tag the document itself. CB-PREPARSED: option *names* are the verbatim spans, `None` descriptions | follows | M-R2 D2: ids cost +20–35 % tokens, buy cheap repetition and keep ≈ 0.97–1.00 | primary-doc · measured | Each excerpt repeats copy text (B02 step 1 13,920 tokens vs 10,575 full text) and makes the state bigger (see R14) | Tagged-unit state (CB-FIND) instead of an excerpt map, for line-level pieces; not for token runs |
| R4 | Option names are read: `everything`, `nothing_fits`, `ask_user` are meaningful; excerpt ids are opaque (`NarrowingPolicy.swift`) | "The option names and their descriptions are both sent to the model"; question ids "are not sent" (DOC-CHOICE, DOC-PRIM) | follows | none recorded (naming); ids from spike | primary-doc | Probably none; `x0042` gives nothing to read, as intended | — |
| R5 | `nothing_fits` as an option inside every Choice (`RequestAssembly.addChoice`) | "Add an `other` or `none of the above` option when the list might not cover every input" (DOC-CHOICE); CB-PREPARSED `none` on every pick. CB-FIND uses a separate `exists` Noul instead, because "Choice probabilities always add up to 1" | follows | M-ABST (20/20 vs 0/40); traps 16/16 (M-R2) | primary-doc · measured | B06: `nothing_fits` 0.38/0.22 against whole bio 0.30/0.21 | — (see R1) |
| R5a | Extraction as a Choice over locally cut, verbatim pieces; every pick checked byte for byte (`PieceCutting.swift`, `Narrowing.isVerbatimPick`) | "when the answer space is bounded, turn extraction into a Choice over the options rather than asking for the value itself" (DOC-JAG #9); "the model cannot choose an omitted value" (REPO-SKILL); CB-PREPARSED: regex over-finds, Choice picks, code copies | follows | `CONTEXT.md` Paste Result, Candidate | primary-doc · measured (55/56 offered at step 1) | — | — |
| R6 | `nothing_fits` and `ask_user` descriptions are compound conditions ("That place asks for one particular thing, and …") (`NarrowingWordings.swift`) | "If a question has two conditions … the value means less" (DOC-NOUL, about Nouls). Typesafe's own `unsure` option: "none of the other options is more likely than not; the packet genuinely supports two of them. Not a way to defer a decision you could make." (REPO-WFE invoice) | partly | V2 → V5 history: the ask sentence fixed K01 (0.93 wrong → ask 0.89) and T01 (M-R2 D3) | primary-doc (Noul page, by analogy) · measured | B06's nothing-fits pull may come from the "one particular thing" clause in the description, not from the place | Shorter, single-fact descriptions in the style of REPO-WFE `UNSURE`; test alone |
| R7 | TWO-ADDR: the chooser fill re-asks the deciding Choice without `ask_user` and without rows that overlap (`ChooserFill.swift`) | No doc on re-asking with options removed. "Several acceptable alternatives can also spread probability" (REPO-SKILL). For "several may apply": "use one [Noul] per label" (REPO-SKILL table); "don't hold the model to arithmetic identities between separate questions" (DOC-JAG #8) | no guidance (the fill) / deviates (Noul per label not used) | F1, Daniel 2026-09-26: second address 0 in 16/16 (`narrowing.md`) | primary-doc · measured | TWO-ADDR (1 of 2 presses). The fill costs one call per row inside the 5 s clock | Per candidate, one Noul ``Is `excerpts.x0042` exactly the thing that place asks for?`` in one parallel request (CB-SKILL `fits::{name}` shape) |
| R8 | Argmax of `choice`; `confidence` ignored; no review band (`Narrowing.decide`, `jev-gateway.md`) | "If all you care about is choosing the best option, you just need to choose the option with the highest confidence" (DOC-AGENT). Confidence = "single dominant answer"; with competing options "that's actually normal" (TALK-LC 0:40:50). Review bands are offered (DOC-CONF, CB-DATE 0.60) | follows (argmax) / deviates (no band, by design) | `CONTEXT.md` Candidate Chooser "Opened by Jev's choice, never by a local type rule"; #52 "no gates" | primary-doc · measured: a confidence gate catches absent answers, not mis-targeted ones (M-CTX: 8/15 misses survive 0.75) | C04/R10 are paste-and-wrong at 0.30–0.44; a band would send them to the chooser | Log-only: top-to-second ratio (DOC-CONF) per step; check offline whether misses separate |

### 3b. Instructions

| # | jevpaste does (file) | TS says (source) | Verdict | Our recorded reason | Evidence | May cost us (`inferred`) | Candidate for #52 (not run) |
|---|---|---|---|---|---|---|---|
| R9 | One instruction, 150 words, 8 sentences: if one particular thing → exact; else least extra; if not one thing → everything; two exact → `ask_user` (`NarrowingWordings.r2b`) | "Ask for one snap judgment per question … a signal to break the task into small questions and compose the answers in code" (DOC-PRIM); "probably the most important concept" (DOC-HOW); "almost always … the question is actually like a compound question" (TALK-TD 0:24:28); counterweight: "A bounded action selection or contextual interpretation is valid; atomic does not mean … a one-sentence limit" (REPO-SKILL) | deviates (letter) / partly (skill file) | M-EXPL D3: V0 3/1/5 on 9 failure cells → V5 28/2/2 on 32 screens; V5 frozen at Gate A | primary-doc · measured (tuned cells; held-out 36/36) | The branches are one hidden judgement ("does that place ask for one particular thing?") that C04/R10/B06 split on | Ask that judgement as its own Noul in the same request, logged only (not a gate, which policy B was); keep V5 as is |
| R10 | Place-neutral: no field, value or app vocabulary; "the place where the text cursor is", "if that place asks for one particular thing" (`NarrowingWordings.swift` header) | Literal reading: "state the exact condition … Put boundary cases in the criteria" (DOC-JAG #1). Indirection: "A question about a property of a property … costs accuracy … identify the relevant parts of state by name" (DOC-JAG #4). "the question should name the narrowest fact that decides it. Here the wording is the difference between 17 blocks and 12" (CB-AUTOFMT) | partly | Design rule (Jev-first, no meaning rules); V5 "text cursor" preamble beat V2 on W01–W03, N02 (M-EXPL) | primary-doc · measured | "What does that place ask for" is a hop through `target_context`. V7 named the keys and did not help (§4). "One particular thing" is a judgement about the place, not a fact in the text | Name a narrower fact, CB-AUTOFMT style, in a logged side Noul (see R9) |
| R11 | Backticked state names: `` `source_document` ``, `` `target_context` ``, `` `excerpts` ``, `` `current_piece` `` | "name it in the `instructions` with a dot-and-index path to its key, including the backticks" (DOC-PRIM); "in the questions I always … like the back ticks" (TALK-LS 1:05:47) | follows | Spike wording | primary-doc | — | — |
| R12 | Later steps: `instructions = {current_piece, question}` (`ChoiceQuestion.Instructions.onPiece`) | "When a value comes from a database, put it in its own field instead of splicing it into a string template" (DOC-HOW); `potential_duplicate` pattern (DOC-NOUL). Cost: "every different nested level of structure is harder to reason about" (TALK-LS 1:01:54) | follows | Round-1 design | primary-doc | One level of nesting; size of the effect `unknown` | — |
| R13 | Same wording at every step, in every parallel Choice, in the follow-up; the fill drops one sentence (`NarrowingWordings`) | "Use the same four questions for every query. Only the state changes" (CB-RAG); "a change of policy is a constant edit … not a reworded question" (CB-RAG); "Adding supplementary data can help make questions distinct" applies when questions should differ (DOC-HOW) | follows | M-R2 ("Follow-up choice: the wording of the step it follows") | primary-doc | — | — |
| R14 | Length ≈ 150 words | "Keep questions short" (DOC-HOW). Typesafe's own production options run to ~70 words each, with "Not this:" lists (REPO-WFE `PRICE_BASIS_TEXT`) | partly | none recorded | primary-doc (conflicting practice) | `unknown` | Not a lever on its own; any shortening is a new wording (R9) |

### 3c. State

| # | jevpaste does (file) | TS says (source) | Verdict | Our recorded reason | Evidence | May cost us (`inferred`) | Candidate for #52 (not run) |
|---|---|---|---|---|---|---|---|
| R15 | Whole `source_document` at every step, also when `current_piece` is two characters (`NarrowingRequest`, `narrowing.md` "document order carries meaning") | "Include only the context relevant to the current questions … avoid distractions and context rot" (DOC-HOW); "Accuracy falls as the state grows with content unrelated to the decision" (DOC-JAG #5); Doom demo: granular state "did cause the overall intelligence to drop" (TALK-LC 0:45:50) | deviates (later steps) / follows (step 1: "Put related information together when the decision requires comparing", DOC-STATE) | Removing the source broke "Current role" (6/7) and gave a confident wrong 0.97 (M-CTX D; M-GRAN list_only) | primary-doc · measured (step 1 only) | Later-step keep was weak before `r2b` (0.54–0.72); A04 picked `7` over `77` (M-R2 Table 1). Not tested with a smaller state | Later steps: state = `current_piece` with a bounded window around it plus `target_context`; A/B on the confirm step only |
| R16 | `target_context` object every step: label, placeholder, heading, sibling labels, surrounding text, app, window title (`TargetContextReader.swift`) | State as material for "a panel of experts"; "The state contains the content and supporting facts. Questions define the judgments" (DOC-STATE); literal reading needs the exact condition (DOC-JAG #1) | follows | M-CTX: label only 0/6 on underdetermined labels, + placeholder 4/6, + heading and siblings 6/6 | primary-doc · measured | Long `surrounding_text` is also a distractor (R15); `unknown` size | — |
| R17 | `excerpts` map with every piece of the request; 194–330 pieces at step 1 (M-R2 D1) | Same as R15; "pay for that state once and ask lots and lots of questions about each [id]" (TALK-LS 1:38:36) | partly | M-R2 D2 (form) | primary-doc (two signals) | Several thousand tokens of near-duplicate text per step | See R3 |
| R18 | Key order `source_document`, `target_context`, `excerpts` (`stateJSON`) | Nothing documented on key order (`unknown`); Typesafe's own states put the query or conversation first (CB-RAG, REPO-WFE), without comment | no guidance | Spike order, pinned by replay tests | — | `unknown` | Not worth a lever on its own |
| R19 | English instructions over often-German copies, labels and forms | "English is the primary training language … test on your own content … pay close attention to Confidence" (DOC-MODELS) | partly | none recorded; German address/form cells A01–A14 pass, except A04 in frozen `r2` (M-R2) | primary-doc · measured | A12 `Top 11` and B06 "third person" are language/culture judgements (M-R2 expectation questions) | Held-out cells with German long-form text (cover letter, Lebenslauf) in #52's fresh set |

### 3d. How many questions, and in what order

| # | jevpaste does (file) | TS says (source) | Verdict | Our recorded reason | Evidence | May cost us (`inferred`) | Candidate for #52 (not run) |
|---|---|---|---|---|---|---|---|
| R20 | Several steps; each step's options depend on the last pick (`Narrowing.swift`) | Second requests are "the exception"; real when the answer decides "the next question's options"; CB-HIER "uses each Choice answer to decide which options the next request offers" (DOC-PRIM). "narrow in two stages: pick the section first, then the span" (CB-PREPARSED) | follows | #49/#50 | primary-doc · measured (mean 1.74 calls) | — | — |
| R21 | Greedy: argmax each step; the piece can only shrink (`Narrowing.decide`) | Greedy: "One early mistake cannot be recovered." Beam K=3 by geometric-mean path probability: 4/4 vs greedy 2/4 (CB-HIER) | deviates | none recorded | primary-doc | C03 (step 1 line 0.39, then keep 0.70); A12 in round 1 (too big, then kept) | Beam of 2–3 paths through steps (spec fan-out already pays for the next step of the top 3) |
| R22 | Parallel choices over split options, then one follow-up over carried pieces (`StepPlanner`, `FollowUp.swift`) | "split it into chunks and rank each one, then run this same shortlist step over the winners" (CB-SKILL); the second pass puts "the same question to better evidence" | follows (shape) / partly (no better evidence) | M-R1, M-R2 | primary-doc · measured | R10 (255/3: whole 0.37, About paragraph 0.04) | Follow-up options carry their text (full-text form) while ids stay in parallel choices, as CB-SKILL does |
| R23 | Carry rule compares p of the same piece across *different* Choices and ranks by it (`ChoicesOfOneStep.carriedPieces`) | "don't hold the model to arithmetic identities between separate questions" (DOC-JAG #8); Choice is relative to its own options (DOC-CHOICE) | partly | none recorded | primary-doc | Only the order and spec selection; the follow-up re-asks every carried piece | — |
| R24 | Independent parallel questions assumed | "Every answer is independent … add or remove questions without changing the others' results" (DOC-PRIM) | follows | — | primary-doc · measured: same state and question, other sibling questions: median max-diff 0.03, same as identical repeats 0.02 (M-RAW) | — | — |
| R25 | Speculative next step for the 3 most likely carried pieces (`Narrowing.followUp`) | Speculative fan-out (DOC-FAN); "State each speculative premise explicitly" (REPO-SKILL) | follows | 33 calls saved in matrix (M-R2) | primary-doc · measured | — | — |
| R26 | One way of asking per decision; no repeat-and-average | "Ask each decision one way; enforce identities in code" (DOC-JAG #8), but CB-SKILL averages three Nouls "each asking a different way" | follows (#8) | — | primary-doc (two practices) | — | — |
| R27 | Composition in code: agreement rule, carry ≥ 0.01, width 3, byte checks (`NarrowingPolicy`) | Compose in code; "thresholds … depend on your domain … test with your own data" (DOC-CONF); "Treat cookbook thresholds … as examples" (REPO-SKILL) | follows | Spike values; never fitted on labelled data | primary-doc | `unknown` | Fit carry and width on M-RAW offline |

### 3e. Model, route and robustness

| # | jevpaste does (file) | TS says (source) | Verdict | Our recorded reason | Evidence | May cost us (`inferred`) | Candidate for #52 (not run) |
|---|---|---|---|---|---|---|---|
| R28 | Direct: `jev-1.13.0`. Gateway: `typesafe-ai/jev` (`JevEndpoint.swift`) | "If you have tuned confidence thresholds against a specific version, pin that version's ID … The response's `model` field reports the versioned ID" (DOC-MODELS). Gateway answers `model: typesafe-ai/jev`, no version (P3–P4, M-RAW). Gateway serves from `typesafe-ai` or `digitalocean`; `"only": ["typesafe-ai"]` restricts it (VERCEL-EVAL, VERCEL-CAT) | follows (direct) / deviates (Gateway) | `jev-gateway.md`: "pinned … never `jev-latest`"; the Gateway row is labelled pinned but is not | primary-doc · measured: on identical requests DigitalOcean moved p by a median of 0.15 (p90 0.35, max 0.67) and changed the choice in 22/127 pairs; Typesafe-only pairs: median 0.02, 13/491 (M-RAW) | C04 r0 (miss) had its deciding follow-up on DigitalOcean, r1 (hit) on Typesafe (M-RAW; n=1). Near-tie cells B06/N03 flip | Send `providerOptions.gateway.only: ["typesafe-ai"]`; rerun the replay cells; log `finalProvider` |
| R29 | Ties in `ranked`/carry broken by Jev's listing order (`FollowUp.swift`; `jev-gateway.md` "it breaks ties in Core") | `probabilities` is a `map<string, number>` (DOC-API); DOC-CONF says a Choice's options have "no particular order" (unlike Score levels); no page defines the response order | deviates (relies on an undefined order) | `jev-gateway.md` | primary-doc · measured: typesafe-ai upstream order differs between identical calls (same 29/491); option order 74/1540; DigitalOcean alphabetical 212/212 (M-RAW; P1–P4) | Arbitrary speculative picks on ties (latency only). Correctness only if > 252 pieces are carried (never seen) | Break ties by document order (as the follow-up's options already are) |
| R30 | Replay tests expect byte-identical requests; live tests accept one alternative on near-tie cells (`jev-gateway.md`) | "determinism … I believe that to be the wrong north star … robustness" (TALK-LS 0:43:17); CB-CCHOICE: Jev flips on 2 of 8 questions over 15 repeats | follows | Run log 2026-09-27 | primary-doc · measured (M-RAW repeats) | — | — |
| R31 | Copy may carry instructions; only verbatim pieces can be pasted | "State is data … an injected instruction … can move the answer … be explicit in the criteria. Test" (DOC-JAG #6) | follows | M-CTX: 0/17 followed injected text; it took up to 0.2 of the mass | primary-doc · measured | An injected line can drag a near-tie (C04-like) across | Two held-out cells with an instruction line inside the copy |
| R32 | All wordings, ids and tunables in `NarrowingPolicy`; "a change here is a new spike round's decision" | "Put the constants (questions and thresholds) in a single place" (DOC-AGENT); "copy … into like one centralized place" (TALK-LC 0:28:05); CB-SKILL: "This string is a measured input … Editing a word here silently invalidates the shipped results" | follows | `NarrowingPolicy.swift` header | primary-doc | — | — |
| R33 | Settings Test: one Choice, one option, "Choose the only option." (`JevConnectionTest.swift`) | — | no guidance | Cheapest request | — | None | — |

## 4. Where our measurements confirm or contradict Typesafe

| Our measurement (source) | Typesafe guidance it touches | Reading |
|---|---|---|
| **The id form, not the wording, fixed the weak keep.** A04 `77` keep alone: L0 0.52, L3 (wording) 0.53, L1 (text in option) 0.63, **L2 (keep as an excerpt id like every other option) 0.97** (M-R2 Table 2) | "Use the same field names across options so the model can compare them directly" (DOC-HOW) | **Confirms.** One odd-shaped option among 250 alike ones lost probability. Making the options alike fixed it (`inferred` mechanism) |
| **V7 (V5 + naming which `target_context` keys describe the place).** On its 5 cells (C03, C04, W01, W03, N02): V7 3/0/2; V5 on the same cells the same or one C04 screen better; in layout "cont" V7 C04 0.64 hit, V5 0.33 miss (M-EXPL) | "identify the relevant parts of state by name" (DOC-JAG #4); "only the context … needed" (DOC-HOW) | **Neither.** The brief's "added context and got worse" is not borne out at this n; V7 was simply not better. Not adopted |
| **First of two equal candidates takes all the weight**: second address 0 in 16/16 (F1); 3 equal emails 0.91–0.95 on one (M-ABST); P1 0.97 / 0.03 | "Several acceptable alternatives can also spread probability" (REPO-SKILL) | **Contradicts** that sentence for exact duplicates of a role. Typesafe's general tool for it is a Noul per label (R7) |
| `ask_user` sentence: K01 0.93 wrong → ask 0.89; T01 0.34 wrong → ask 0.75 (M-EXPL V0 → V5) | Literal reading: "state the exact condition" (DOC-JAG #1) | **Confirms**: once the condition was written down, it was chosen |
| Placeholder + heading + siblings: 0/6 → 6/6 on underdetermined labels; confident wrong answers up to 1.00 without them (M-CTX) | Literal reading; "Higher confidence does not establish which answer is correct" (DOC-SCORE) | **Confirms** |
| Dropping the source text: "Current role" wrong, gmail pick 0.97 confident wrong (M-CTX, M-GRAN) | "Put related information together when the decision requires comparing" (DOC-STATE) versus "only what the question needs" (DOC-JAG #5) | **Confirms the first**, and bounds the second: document order is needed context at step 1 |
| 255 overlapping candidates: 7/7, top-1 0.997 (M-GRAN); part-against-whole misses at 0.3–0.45 (M-R2) | Overlap caution (TALK-LC, TALK-TD) | **Both**: overlap is harmless when one value is clearly asked for, and the problem when the size of the thing is the question |
| Policy B (a separate 3-way place choice deciding whole/nothing) added no hit and lost N02 (M-R2) | Decompose into narrow questions (DOC-HOW) | **Weakly contradicts**, but P3 was itself a 3-way compound question used as a gate, not a narrow fact |
| Identical requests are not deterministic: Typesafe upstream median Δ 0.02, choice flips 2.6 %; earlier small spikes saw 14/14 identical (M-GRAN) | "robustness … not determinism" (TALK-LS); CB-CCHOICE flips 2/8 | **Confirms**; our older "deterministic" note held only for small requests |
| Questions in one request do not move each other (R24, M-RAW) | "Every answer is independent" (DOC-PRIM) | **Confirms** |
| Speculative fan-out answered 33 next steps (M-R2) | DOC-FAN | **Confirms** |
| Injected instruction never followed, but moved up to 0.2 of the mass (M-CTX) | DOC-JAG #6 "can move the answer" | **Confirms** |

## 5. What stays unknown

| Question | Why unknown |
|---|---|
| Does option position in `criteria` change probabilities (first listed wins)? | No Typesafe doc. F1 and P1 had the first address both first in the document and first among the options; not separated |
| What the `probabilities` order means on the Typesafe upstream | Not documented; varies between identical calls (M-RAW). Ties after 2-decimal rounding are common: 852 of round 2's 1,547 Choice answers have a tie among non-zero values |
| Which model version DigitalOcean serves for `typesafe-ai/jev`, and why its answers differ | Not documented by Vercel or Typesafe; the Gateway reports no version |
| Whether a long multi-branch instruction costs accuracy against several short questions *for this task* | Typesafe says so in general; no Typesafe measurement on extraction; ours never A/B'd it |
| At what state size accuracy starts to fall | DOC-JAG gives no number; "context rot" is unquantified |
| Cost of one level of nested `instructions` | TALK-LS says "harder to reason about", no number |
| Whether German instructions would do better on German content | DOC-MODELS only says English is best |
| Calibration of probabilities spread over nested, overlapping options | No Typesafe statement; their calibration claims are per question, across many predictions (BLOG, DOC-CONF) |
| When a newer Jev ships, and whether 1.13.0 gets LTS | TALK-LS 0:50:08: "might temporarily LTS"; no date; models page lists 1.13.0 only |
| Whether `providerOptions.gateway.only` changes routing on `/v1/evaluate` in practice | Documented by Vercel (VERCEL-EVAL); not probed |

## 6. Probes (4 of the 10 allowed)

Purpose: settle Q6 (order of `probabilities`) on both routes. Every probe sent the same request: state `{source_document:
"Contact: anna@example.org or a.berg@example.com", target_context: {field_label: "Email"}, excerpts: {opt_e…opt_c}}`,
one Choice with 5 id options `opt_e, opt_a, opt_d, opt_b, opt_c` (`null` descriptions) asking which id is the email that
belongs in the field. No jevpaste wording was evaluated.

| Probe | Route | Answered `model` | Upstream | Result | `probabilities` order |
|---|---|---|---|---|---|
| P1 | Typesafe direct, `jev-1.13.0` | `jev-1.13.0` | — | `opt_a` (anna) 0.97, `opt_d` 0.03 | a, c, e, d, b |
| P2 | same, repeated | `jev-1.13.0` | — | same values | c, d, e, a, b |
| P3 | Gateway, `typesafe-ai/jev` | `typesafe-ai/jev` | typesafe-ai | 0.97 / 0.03 | a, e, d, b, c |
| P4 | same, repeated | `typesafe-ai/jev` | digitalocean | 0.91 / 0.09 | a, b, c, d, e (alphabetical) |

Reading (`measured`): the order is neither option order nor probability order. On Typesafe it changes between identical
calls. On DigitalOcean it is alphabetical. The same route-dependent pattern holds over the 1,752 recorded Choice answers (R29).
