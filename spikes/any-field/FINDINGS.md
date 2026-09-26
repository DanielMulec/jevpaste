# Spike findings — can Jev extract the excerpt for any field, or does it need an LLM?

Ticket: [#46](https://github.com/DanielMulec/jevpaste/issues/46). Decision it serves:
[#31 resolution](https://github.com/DanielMulec/jevpaste/issues/31#issuecomment-5844214504). Branch
`spike/any-field-extraction` (never merged). **Data only — no product decision.**
Tags: **[measured]** = in `results/raw.jsonl`; **[inference]** = my reading of it.

## Verdict against Daniel's fixed criteria (Engine J, gate wording v7, threshold 0.5)

| criterion | result |
|---|---|
| Address, signature and résumé: every listed field hits in both runs | **FAIL**: 10 misses out of 52 [measured] |
| `contains_more` fires correctly on every cell (2×2 off-diagonals empty) | **FAIL**: 17 wrong out of 100 [measured] |
| Negative cells end in `none_of_these` / No Suitable Match | **PASS**: 12 of 12 [measured] |

Breakdown by item [measured]:
- Signature: 18/18. Order confirmation: 18/18. Two-line tickets: 2/2.
- Address: 22/28.
- Résumé: J alone 14/20; in production 10/20, because the production free-text override pastes the whole
  résumé into About, Profile summary and Description.
- Bio: 11/16. Cover letter: J alone 6/10, in production 8/10.
- Overall: J 91/112, production 89/112.

### Misses against the criteria, by name [measured]

| cell | run | what was pasted | why |
|---|---|---|---|
| Vorname → `Mira` | 0, 1 | `Mira Holzner` | gate stayed low (0.30 / 0.13), so stage 2 never ran |
| Nachname → `Holzner` | 0 | `Mira Holzner` | gate 0.19 (run 1: 0.65 → `Holzner` ✅) |
| Straße → `Prankergasse` (borderline) | 0, 1 | `Prankergasse 77` | gate 0.36 / 0.33 |
| Ort → `Graz` | 1 | `8020 Graz` | gate 0.36 (run 0: 0.55 → `Graz` ✅) |
| About → the About paragraph | 0, 1 | the whole résumé | free_text 0.84 / 0.82 ≥ 0.8. J alone would also miss: the gate fired (0.52 / 0.50) on a paragraph longer than 12 tokens, and stage 2 answered none |
| Country of residence → `Austria` (borderline) | 0, 1 | nothing (No Suitable Match) | stage 1 chose the EXPERIENCE line at p 0.29 / 0.30; contains_value 0.50 / 0.39; gate low |

Every other listed field hit in both runs. That includes all 8 signature fields, and PLZ, Hausnummer,
Straße und Hausnummer, Birthdate, Birthplace and Nationality [measured].

## Setup

- **Fixtures** (`fixtures.py`, all synthetic): 7 items and 56 cells, 12 of them negative.
  - The five briefed items: address block, email signature, résumé header + About, order confirmation, profile
    bio.
  - The ticket's two-line prefix+email case (`tickets`).
  - The supervisor's long-form additions: résumé Profile summary / Biography / Description; bio Biography /
    About me / Short bio; a cover-letter item with 5 cells.
  - Every cell carries a production-shaped `target_context`: `app_name` "Google Chrome", a form
    `window_title`, `field_label`, optional `placeholder`, `section_heading`, `sibling_field_labels`, and
    `surrounding_text` of 300–1200 characters.
  - Expected values are used **only for scoring and logging** and are never sent. No field vocabulary exists
    anywhere in J.
- **Structural Candidates** (`spans.py`): a Python mirror of `docs/design/candidate-derivation.md`, rules 1–10.
  - I checked it line by line against the Swift sources on `main` (`StructuralExcerpts`, `HeadingLikeLine`,
    `LabelledLine`, `Excerpt` ordering and dedup, `CandidateType` regexes).
  - Option descriptions follow production: line breaks are joined with a space and the text is cut to 255
    characters. Option ids are `c000…`.
- **Stage-2 spans:** tokens are bounded at whitespace and at `, ; : ( ) " ' < > /`. Spans are 1–12 tokens,
  byte-exact slices, deduplicated, and capped at ≤ 254 with the longest dropped first. `none_of_these` is added.
- **Stage 1** is one Jev call with 4 questions:
  - `paste` (choice, wording widened to "is or contains")
  - `contains_value` (production, unchanged)
  - `free_text` (production, unchanged)
  - `contains_more` (the new gate)

  Core order is unchanged: free_text ≥ 0.8 pastes the whole item; then, if contains_value < 0.5 or the choice is
  none → No Suitable Match; then, if contains_more ≥ 0.5 → stage 2; otherwise the Candidate is pasted.
- **Runs:** 2 runs per cell. Stage 2 also ran under the free-text override so that J is measured on every cell
  (flagged †; not counted as a production call).
- **Jev is not deterministic** [measured]. Identical requests gave, for example, gate 0.19 vs 0.65 (Nachname) and
  0.55 vs 0.36 (Ort). A single run is not a reliable measurement.

## Exact wording of every question (verbatim)

**Stage 1 `paste` (choice).** The instructions:
> The user copied `source_document` and is pasting into `target_context`. Every option is an exact contiguous excerpt of `source_document`. Choose the single excerpt that is exactly the value belonging in that field, as the user would type it. If no option is exactly that value, choose the shortest option that contains it. Do not choose an excerpt that is merely related to the field.

The `none_of_these` option:
> None of the listed excerpts is or contains the value that belongs in the target field. Choose this when the source document does not contain the value.

**`contains_value` (production, unchanged).** The instructions:
> Does `source_document` contain some exact contiguous excerpt that is the value belonging in `target_context`? Answer true only if such an excerpt exists and could be inserted verbatim into the field.

Criteria:
- true: "An exact excerpt of the document is the value for this field."
- false: "No excerpt of the document is the value for this field."

**`free_text` (production, unchanged).** The instructions:
> Judge only the place described by `target_context`, not `source_document`. Is `target_context` a free-text place — a chat or message composer, a document or text editor, a code editor, a terminal — where the user would paste whatever they copied, as it is? Or is it a field that expects one specific value, such as a name, an email address, a phone number, an address line or a single short entry?

Criteria:
- true: "A free-text place: the user would paste whatever they copied, whole."
- false: "A field for one specific value."

Caveat: this production question is the only place where field types are named. It was kept verbatim, as the
brief requires.

**`contains_more` — v7, the wording used in the matrix.** The instructions:
> Find the text in `source_document` that belongs in `target_context`, and look at the line it sits on (or the value after that line's `Label:` prefix, or its paragraph when the value spans several lines). Does that line hold more than what belongs in the field, so the user would have to delete part of it after pasting? Answer yes when the line holds the value plus other words, numbers, a label or a prefix. Answer no when the line is exactly the value, when the value is a whole paragraph, or when the document holds nothing for the field. Shapes, with `A` standing for what belongs in the field: the line `A B` — yes; the line `B A` — yes; the line `B A C` — yes; the line `A` — no; the paragraph that is exactly `A` — no.

Criteria:
- true: "The line (or `Label:` value, or paragraph) holding the value also holds text that must be deleted."
- false: "The value is that whole line, `Label:` value or paragraph on its own, or the document holds no value for this field."

Why it is self-contained: Jev answers the questions of one call independently ("parallel questions"), so a boolean
cannot refer to "the Candidate chosen in `paste`". The brief's literal idea — "does the chosen Candidate contain
more than what belongs in the target?" — was approximated as follows:
- v1–v3 and v7 name the structural units themselves.
- v4 embeds the Candidate list in the boolean.

**Stage 2 `span` (choice).** The instructions:
> The user copied `source_document` and is pasting into `target_context`. Every option is an exact contiguous excerpt of `source_document`, cut at word and punctuation boundaries. Choose the single excerpt that is exactly the value belonging in that field, as the user would type it: nothing of the value missing, and no neighbouring words, labels or other values included.

The `none_of_these` option:
> None of the listed excerpts is exactly the value that belongs in the target field.

**Stage 3** reuses the v7 gate and the stage-2 choice word for word. The only difference: when the gate is asked
about a piece, `source_document` is that piece, so "the line it sits on" means the piece itself.

**J′ (per-span boolean, prepared, not run — see below).** The instructions:
> The user copied `source_document` and is pasting into `target_context`. Is the exact text {span} the {field} — the complete value belonging in that field, with nothing extra, as the user would type it?

**L prompt.** The instruction below is followed by a JSON block `{"item": …, "target_context": …}`:
> You fill one form field from text the user copied. `item` is the copied text; `target_context` describes the focused field and its page. Return exactly one contiguous substring of `item` that belongs in this field, verbatim (same characters, spacing and line breaks; nothing added, removed or reformatted), or NONE if the item holds nothing for this field. Answer with JSON only: {"excerpt": "<substring>"} or {"excerpt": "NONE"}.

Gate wordings v1–v6 are recorded verbatim in `run.py` (`CONTAINS_MORE_VARIANTS`, `contains_more_v4`).
**v5 and v6 are withdrawn**: their worked examples named field types (first name, postcode, email, amount, bio),
which violates the rule "no field vocabulary in J". A partial v6 matrix (37 cells of run 0) is kept in the log and
reported below only as history.

## Gate tuning history [measured]

Cells marked ▲ should fire the gate; cells marked ▽ should stay low.

| cell | | v1 | v2 | v3 | v4 | v5 ✗ | v6 ✗ |
|---|---|---|---|---|---|---|---|
| Vorname | ▲ | 0.50 | 0.40 | 0.44 | 0.29 | 0.64 | 0.85 |
| PLZ | ▲ | 0.29 | 0.48 | 0.58 | 0.55 | 0.68 | 0.46 |
| Land | ▽ | 0.27 | 0.12 | 0.17 | 0.17 | 0.17 | 0.17 |
| Straße und Hausnummer | ▽ | 0.32 | 0.13 | 0.25 | 0.42 | 0.17 | 0.18 |
| Phone | ▲ | 0.94 | | 0.95 | 0.91 | 0.86 | 0.85 |
| Nationality | ▽ | | | 0.43 | | 0.08 | 0.10 |
| Bio | ▽ | | | 0.43 | | 0.50 | 0.28 |
| Amount | ▲ | | | 0.89 | | 0.40 | 0.65 |

I did not re-tune after the withdrawal because the budget did not allow it. v7 went straight into the matrix. The
tuning cells are part of the matrix: there is no held-out set.

## Gate 2×2 (v7, positive cells, both runs, threshold 0.5) [measured]

| | gate fired | gate low |
|---|---|---|
| needs a sub-span | 50 | **8** |
| expected is a whole Candidate | **9** | 33 |

- P(contains_more) when a sub-span is needed: min 0.13, median 0.90.
- P(contains_more) when the expected text is a whole Candidate: max 0.66, median 0.34.
- The two groups overlap, so no threshold separates them.
- Negatives: 0.12–0.37, all low.

Off-diagonal cells, split by consequence:
- **Missed fires (8), all harmful** (a whole line is pasted): Vorname ×2, Nachname r0, Straße ×2, Ort r1,
  Country ×2.
- **False fires (9):**
  - 4 harmless: Nationality ×2, where stage 2 offered 1 span (`Austrian`) → hit; and Name `Theo Brandner` ×2,
    where stage 2 kept the whole line → hit.
  - 5 harmful: Candidates longer than 12 tokens, which stage 2 cannot offer whole. These are the About
    paragraph ×2 (also overridden by free_text), the first line of the Availability paragraph ×2 (15 tokens;
    the expectation there is arguable — see L) and paragraph 1 for Short bio r1.

## Stage 2 (the batched span choice) [measured]

- Stage 2 ran 59 times. The expected span was among the offered spans 52 times, and **Jev picked it all 52 times**
  (the lowest winning probability was 0.52).
- All 7 stage-2 misses happened because the expected text was **not offered**: a Candidate longer than 12
  tokens ×5, and `Innsbruck.` ×2.
- Because stage 2 never failed when the answer was offered, **the J′ condition ("batched stage-2 choice unreliable
  on ≥ 3 cells") was not met, and J′ was not run.**
- Amount: Jev picked `129,90` over `EUR 129,90` both times (0.56 vs 0.41; 0.52 vs 0.45).
- Bio fields:
  - Stage 1 chose **both paragraphs (the whole item)** for Bio, About me and Biography.
  - It chose **paragraph 1** for Short bio, the field with the 280-character hint.
  - For the résumé's About, Profile summary, Biography and Description, stage 1 always chose the About paragraph.
- Two-line tickets: the first email both times.

## Choice-only J — what the data says about dropping the yes/no gate [measured + inference]

**Shadow stage 2** was run during the withdrawn v6 matrix. Whenever the gate stayed low and the chosen Candidate was
≤ 12 tokens (so the whole Candidate is itself one of the spans), stage 2 was asked anyway. It went **10/10**:
- It kept the whole Candidate when that was right: `Top 11`, the URL, `Prankergasse 77` for "Straße und
  Hausnummer", `Anna Reisinger`.
- It cut when the gate had been wrong: `Prankergasse`, `77`, `Graz`, the email and the web address from
  `… | …`, and the IBAN without its `IBAN` label. [measured]

The stage-2 wording contains no field vocabulary, so this result stays valid under the v7 rule. The v7 false fires
on `Austrian` and `Theo Brandner` also kept the whole Candidate [measured].

**[inference]** For Candidates ≤ 12 tokens, a J without the gate — stage 1 choice, then a span choice that always
contains the whole Candidate — would have removed all 8 harmful missed fires in this matrix. The residual risks:
- **Long pieces:** a Candidate longer than 12 tokens (a paragraph, or a long line) is not among its own spans. A choice-only form would have to
  add the whole piece as one extra option ("spans + whole piece in one choice"). That option was **not measured**;
  the 5 harmful false fires show what happens without it.
- **Cost:** every multi-token paste takes 2 calls instead of 1.51 on average. Pastes that needed stage 2 took a
  median of 1184 ms against 945 ms over all pastes (see Latency).
- **Single-token Candidates:** skip stage 2, as stage 3 already does.

## Reachability — was the expected excerpt offered at all? [measured, offline + per run]

- Every positive cell's expected excerpt is either a whole Candidate or a span of some Candidate, with two
  exceptions:
  - **B02 City `Innsbruck`.** The token is `Innsbruck.` because `.` is not a cut point. The excerpt is reachable
    only as a stage-3 substring.
  - **C01 Cover letter body.** It has 86 tokens, more than 12. The whole item, which is an accepted answer, is a
    Candidate.
- **Unreachable under stage 1–3 rules: 1 cell (C01, too long).** This count is kept apart from Jev misses.
- Spans per stage-2 call: min 1, median 20, max 254 (n = 59).
- The same parents cut with the dropped extended set `@ . - _` would give min 1, median 21, max 254. This is an
  offline count only; no calls were made, per the supervisor's switch to stage 3.

## Stage 3 — recursive refinement below the token [measured]

| cell | start piece | level 3: gate / options / pick (p) | level 4 gate | final | calls per paste |
|---|---|---|---|---|---|
| N01 Straße (`Prankergasse77`) | stage-1 Candidate (single token) | 0.73 / 100 / `Prankergasse` (0.51) | 0.14 → stop | `Prankergasse` ✅ | 3 |
| N02 Hausnummer (`Prankergasse77`) | stage-1 Candidate (single token) | 0.88 / 100 / `77` (0.82) | 0.14 → stop | `77` ✅ | 3 |
| B02 City | stage-2 pick `Innsbruck.` | **0.10 → stop** | – | `Innsbruck.` ❌ | 3 |
| N03 Benutzername (borderline) | stage 1 chose none (contains_value 0.46) | – | – | none | 1 |

- **B02:** the gate does not treat a trailing `.` as "more". A diagnostic level-3 choice was run anyway; it is not
  part of J and is logged as `stage3_forced_choice`. It picked `Innsbruck` at 0.98 out of 54 options.
- **Latency:** stage-3 calls took a median of 893 ms (n = 5).
- **Calls per paste** for a level-3 cell: 3 when the Candidate is a single token (stage 1, level-3 choice,
  level-4 gate). It would be 5 after a multi-token stage 2 (stage 1, stage 2, gate, choice, gate).

## Chooser noise (same-type spans next to the stage-2 winner) [measured]

- Phone and Mobile, both runs: **2** each. Offered alongside were the other phone and `660 1112233`, which matches
  the production phone rule (10 digits). The production chooser would open in these 4 of 4 pastes.
- Two-line tickets, run 1: **1** (the other email). This is the intended chooser case.
- Every other stage-2 winner: 0. Most winners have no type at all, which never triggers the chooser.
- No stage-1 winner had same-type alternatives.

## Latency (client round trip through the Gateway, excluding 429 waits) [measured]

| call | warm | cold |
|---|---|---|
| stage 1 (4 questions) | n=148, median 564 ms, p90 906 ms | n=13, median 731 ms, p90 1072 ms |
| stage 2 | n=76, median 533 ms, p90 864 ms | – |
| **J total per paste** (production calls only) | n=112, median **945 ms**, p90 1540 ms, max 3181 ms | |
| pastes that needed stage 2 | n=57, median **1184 ms**, p90 1848 ms | |

Free-tier throttling was heavy: 58 retry waits in the final matrix process alone, often 60 s each (`retry-after`),
and one hard failure ("upstream provider … high demand"). The matrix resumes cell by cell. A cell whose stage-1 call
succeeded but whose stage 2 failed had its stage 1 re-billed; this happened once, and the orphan call is counted.

## L rescue (cells J missed or split; 1 run each) [measured]

- **`deepseek/deepseek-v4.1-flash` via the Gateway:** HTTP **403** "Free tier users do not have access to this
  model", persistent after 3 paced retries. Stopped and **not measured**.
- **`openai/gpt-6-luna` via the Gateway:** the same 403. Stopped.
- **Luna fallback `codex exec -m gpt-6-luna --json`** (Daniel's ChatGPT login): exit 1 on all 14 cells, with HTTP
  400 "The 'gpt-6-luna' model is not supported when using Codex with a ChatGPT account". **Not measured.**
- **Substitute, labelled as such:** the Codex catalogue on this login offers `gpt-5.6-luna`, so that model was run
  through the same `codex exec` full agent turn. This is **not the briefed model**.

| cell | J (both runs) | gpt-5.6-luna via codex (substitute) | verbatim | hit |
|---|---|---|---|---|
| Vorname | `Mira Holzner` ×2 | `Mira` | yes | ✅ |
| Nachname | miss r0 | `Holzner` | yes | ✅ |
| Straße (borderline) | `Prankergasse 77` ×2 | `Prankergasse` | yes | ✅ |
| Ort | miss r1 | `Graz` | yes | ✅ |
| About | whole résumé ×2 | About paragraph | yes | ✅ |
| Country (borderline) | none ×2 | `NONE` | yes | ❌ |
| Profile summary | whole résumé (free_text) | About paragraph | yes | ✅ |
| Biography (résumé) | whole résumé / none | About paragraph | yes | ✅ |
| Description | whole résumé (free_text) | About paragraph | yes | ✅ |
| City (bio) | `Innsbruck.` ×2 | `Innsbruck` | yes | ✅ |
| Biography (bio) | none ×2 (contains_value 0.19/0.22) | paragraph 1 | yes | ✅ |
| Short bio | ✅ r0 / partial r1 | paragraph 2 | yes | ❌ |
| Availability | partial span ×2 | first line of the paragraph | yes | ❌ (my expectation, the 2-line paragraph, is arguable) |
| Notes | none, but free_text ✅ | `I am happy to relocate for the role.` | yes | ❌ (no free-text notion in L) |

- **Result:** 10/14 rescued, and 14/14 answers were byte-exact substrings.
- **Latency:** full `codex exec` turn, median **7.05 s**, range 5.1–10.0 s. That is about 7× J's per-paste
  median.

## Calls and cost [measured]

- Billed Jev calls: **291 of 320**. That is 288 logged calls plus 3 smoke calls that the previous worker reported
  but did not log.
  - stage 1: 161, including 3 stage-3 cells
  - stage 2: 76
  - tuning: 35
  - shadow stage 2: 10
  - stage 3: 6, including the 1 forced diagnostic choice
- Jev cost, from Gateway metadata: **$0.0177** for 422,476 input tokens — about $0.00006 per call.
- Production calls per paste in the matrix: mean 1.51; 57 of 112 pastes needed stage 2.
- L: no Gateway spend, because both models were refused. The Codex substitute ran on Daniel's subscription.

## Open questions

1. **Gate reliability:** name-in-line and number-in-line gate probabilities scatter around 0.5 across wordings and
   between identical runs. Is a gate-free J (span choice always offered, including the whole piece) acceptable at
   about 2 calls per paste? The "whole piece as an extra option" variant is unmeasured.
2. **The free-text override** takes About / Profile summary / Description / About me, pasting the whole item
   (free_text 0.80–0.92). For a CV, the whole item is wrong in About, Profile summary and Description; for a bio,
   the whole item was an accepted answer.
3. **Trailing punctuation** (`Innsbruck.`): the v7 gate does not see it as "more", so stage 3 never runs, although
   the level-3 choice would pick the right excerpt.
4. **L:** neither briefed model was reachable. Measuring `deepseek-v4.1-flash` and `gpt-6-luna` needs Gateway
   credits or a direct API.

## Appendix — per-cell table (Engine J, gate v7, threshold 0.5)

Hit = final pasted text byte-equal to the expected excerpt (or a listed accept). `J` = J's own answer; `prod` = after production's free_text ≥ 0.8 override (whole item). s1 = stage-1 choice (prob), more = `contains_more` P(true), free = `free_text` P(true), s2 = stage-2 span (prob, spans offered).

| cell | field | expected | run | s1 (prob) | more | free | s2 (prob, #spans) | J | prod | noise |
|---|---|---|---|---|---|---|---|---|---|---|
| A01_vorname | Vorname | `Mira` | 0 | `Mira Holzner` (0.95) | 0.30 | 0.04 | – | ❌ | ❌ `Mira Holzner` |  |
| A01_vorname | Vorname | `Mira` | 1 | `Mira Holzner` (0.93) | 0.13 | 0.03 | – | ❌ | ❌ `Mira Holzner` |  |
| A02_nachname | Nachname | `Holzner` | 0 | `Mira Holzner` (0.65) | 0.19 | 0.03 | – | ❌ | ❌ `Mira Holzner` |  |
| A02_nachname | Nachname | `Holzner` | 1 | `Mira Holzner` (0.76) | 0.65 | 0.03 | `Holzner` (1.00, 3) | ✅ | ✅ |  |
| A03_strasse ⚠ | Straße | `Prankergasse` | 0 | `Prankergasse 77` (0.95) | 0.36 | 0.05 | – | ❌ | ❌ `Prankergasse 77` |  |
| A03_strasse ⚠ | Straße | `Prankergasse` | 1 | `Prankergasse 77` (0.96) | 0.33 | 0.05 | – | ❌ | ❌ `Prankergasse 77` |  |
| A04_hausnummer | Hausnummer | `77` | 0 | `Prankergasse 77` (0.80) | 0.64 | 0.03 | `77` (1.00, 3) | ✅ | ✅ |  |
| A04_hausnummer | Hausnummer | `77` | 1 | `Prankergasse 77` (0.80) | 0.58 | 0.03 | `77` (1.00, 3) | ✅ | ✅ |  |
| A05_adresszusatz | Adresszusatz | `Top 11` | 0 | `Top 11` (0.99) | 0.16 | 0.05 | – | ✅ | ✅ |  |
| A05_adresszusatz | Adresszusatz | `Top 11` | 1 | `Top 11` (0.99) | 0.15 | 0.06 | – | ✅ | ✅ |  |
| A06_plz | PLZ | `8020` | 0 | `8020 Graz` (0.94) | 0.68 | 0.03 | `8020` (1.00, 3) | ✅ | ✅ |  |
| A06_plz | PLZ | `8020` | 1 | `8020 Graz` (0.96) | 0.62 | 0.03 | `8020` (1.00, 3) | ✅ | ✅ |  |
| A07_ort | Ort | `Graz` | 0 | `8020 Graz` (0.92) | 0.55 | 0.04 | `Graz` (0.99, 3) | ✅ | ✅ |  |
| A07_ort | Ort | `Graz` | 1 | `8020 Graz` (0.91) | 0.36 | 0.04 | – | ❌ | ❌ `8020 Graz` |  |
| A08_land | Land | `Österreich` | 0 | `Österreich` (1.00) | 0.19 | 0.04 | – | ✅ | ✅ |  |
| A08_land | Land | `Österreich` | 1 | `Österreich` (0.99) | 0.14 | 0.04 | – | ✅ | ✅ |  |
| A09_email | E-Mail | `mira.holzner@example.org` | 0 | `mira.holzner@example.org` (1.00) | 0.09 | 0.04 | – | ✅ | ✅ |  |
| A09_email | E-Mail | `mira.holzner@example.org` | 1 | `mira.holzner@example.org` (1.00) | 0.09 | 0.04 | – | ✅ | ✅ |  |
| A10_website | Website | `https://www.miraholzner.example` | 0 | `https://www.miraholzner.e…` (1.00) | 0.09 | 0.07 | – | ✅ | ✅ |  |
| A10_website | Website | `https://www.miraholzner.example` | 1 | `https://www.miraholzner.e…` (1.00) | 0.09 | 0.06 | – | ✅ | ✅ |  |
| A11_telefon | Telefon | `06608405534` | 0 | `06608405534` (1.00) | 0.08 | 0.04 | – | ✅ | ✅ |  |
| A11_telefon | Telefon | `06608405534` | 1 | `06608405534` (1.00) | 0.08 | 0.04 | – | ✅ | ✅ |  |
| A12_strasse_hnr | Straße und Hausnummer | `Prankergasse 77` | 0 | `Prankergasse 77` (0.98) | 0.15 | 0.04 | – | ✅ | ✅ |  |
| A12_strasse_hnr | Straße und Hausnummer | `Prankergasse 77` | 1 | `Prankergasse 77` (0.97) | 0.14 | 0.05 | – | ✅ | ✅ |  |
| A13_passwort_NEG | Passwort | ∅ (none) | 0 | ∅ (none) (1.00) | 0.14 | 0.04 | – | ✅ | ✅ |  |
| A13_passwort_NEG | Passwort | ∅ (none) | 1 | ∅ (none) (0.99) | 0.15 | 0.04 | – | ✅ | ✅ |  |
| A14_fax_NEG | Fax | ∅ (none) | 0 | ∅ (none) (0.98) | 0.13 | 0.05 | – | ✅ | ✅ |  |
| A14_fax_NEG | Fax | ∅ (none) | 1 | ∅ (none) (0.98) | 0.12 | 0.04 | – | ✅ | ✅ |  |
| S01_first_name | First name | `Jonas` | 0 | `Jonas Prell · Product Lead` (0.88) | 0.93 | 0.04 | `Jonas` (1.00, 15) | ✅ | ✅ |  |
| S01_first_name | First name | `Jonas` | 1 | `Jonas Prell · Product Lead` (0.88) | 0.92 | 0.04 | `Jonas` (1.00, 15) | ✅ | ✅ |  |
| S02_last_name | Last name | `Prell` | 0 | `Jonas Prell · Product Lead` (0.77) | 0.91 | 0.04 | `Prell` (1.00, 15) | ✅ | ✅ |  |
| S02_last_name | Last name | `Prell` | 1 | `Jonas Prell · Product Lead` (0.78) | 0.90 | 0.04 | `Prell` (1.00, 15) | ✅ | ✅ |  |
| S03_job_title | Job title | `Product Lead` | 0 | `Jonas Prell · Product Lead` (0.89) | 0.79 | 0.05 | `Product Lead` (1.00, 15) | ✅ | ✅ |  |
| S03_job_title | Job title | `Product Lead` | 1 | `Jonas Prell · Product Lead` (0.89) | 0.72 | 0.05 | `Product Lead` (1.00, 15) | ✅ | ✅ |  |
| S04_phone | Phone | `+43 1 2345678` | 0 | `Phone +43 1 2345678 · Mob…` (0.96) | 0.96 | 0.04 | `+43 1 2345678` (0.99, 44) | ✅ | ✅ | 2 |
| S04_phone | Phone | `+43 1 2345678` | 1 | `Phone +43 1 2345678 · Mob…` (0.96) | 0.96 | 0.04 | `+43 1 2345678` (0.99, 44) | ✅ | ✅ | 2 |
| S05_mobile | Mobile | `+43 660 1112233` | 0 | `Phone +43 1 2345678 · Mob…` (0.96) | 0.96 | 0.04 | `+43 660 1112233` (0.99, 44) | ✅ | ✅ | 2 |
| S05_mobile | Mobile | `+43 660 1112233` | 1 | `Phone +43 1 2345678 · Mob…` (0.97) | 0.96 | 0.04 | `+43 660 1112233` (0.99, 44) | ✅ | ✅ | 2 |
| S06_email | Email | `jonas.prell@example.com` | 0 | `jonas.prell@example.com |…` (0.95) | 0.77 | 0.04 | `jonas.prell@example.com` (1.00, 6) | ✅ | ✅ |  |
| S06_email | Email | `jonas.prell@example.com` | 1 | `jonas.prell@example.com |…` (0.95) | 0.75 | 0.04 | `jonas.prell@example.com` (1.00, 6) | ✅ | ✅ |  |
| S07_website | Website | `www.prell.example` | 0 | `jonas.prell@example.com |…` (0.93) | 0.63 | 0.05 | `www.prell.example` (1.00, 6) | ✅ | ✅ |  |
| S07_website | Website | `www.prell.example` | 1 | `jonas.prell@example.com |…` (0.95) | 0.63 | 0.06 | `www.prell.example` (1.00, 6) | ✅ | ✅ |  |
| S08_iban ⚠ | IBAN | `AT61 1904 3002 3457 3201` | 0 | `IBAN AT61 1904 3002 3457 …` (0.99) | 0.76 | 0.04 | `AT61 1904 3002 3457 3201` (1.00, 21) | ✅ | ✅ |  |
| S08_iban ⚠ | IBAN | `AT61 1904 3002 3457 3201` | 1 | `IBAN AT61 1904 3002 3457 …` (0.98) | 0.87 | 0.05 | `AT61 1904 3002 3457 3201` (1.00, 21) | ✅ | ✅ |  |
| S09_fax_NEG | Fax | ∅ (none) | 0 | ∅ (none) (1.00) | 0.15 | 0.05 | – | ✅ | ✅ |  |
| S09_fax_NEG | Fax | ∅ (none) | 1 | ∅ (none) (1.00) | 0.15 | 0.05 | – | ✅ | ✅ |  |
| R01_full_name | Full name | `Anna Reisinger` | 0 | `Anna Reisinger` (0.99) | 0.23 | 0.04 | – | ✅ | ✅ |  |
| R01_full_name | Full name | `Anna Reisinger` | 1 | `Anna Reisinger` (0.98) | 0.18 | 0.05 | – | ✅ | ✅ |  |
| R02_birthdate | Date of birth | `14 March 1991` | 0 | `Born 14 March 1991 in Linz` (0.92) | 0.89 | 0.03 | `14 March 1991` (0.99, 21) | ✅ | ✅ |  |
| R02_birthdate | Date of birth | `14 March 1991` | 1 | `Born 14 March 1991 in Linz` (0.93) | 0.90 | 0.04 | `14 March 1991` (1.00, 21) | ✅ | ✅ |  |
| R03_birthplace | Place of birth | `Linz` | 0 | `Born 14 March 1991 in Linz` (0.93) | 0.84 | 0.06 | `Linz` (0.99, 21) | ✅ | ✅ |  |
| R03_birthplace | Place of birth | `Linz` | 1 | `Born 14 March 1991 in Linz` (0.91) | 0.88 | 0.06 | `Linz` (0.99, 21) | ✅ | ✅ |  |
| R04_nationality | Nationality | `Austrian` | 0 | `Austrian` (0.85) | 0.59 | 0.05 | `Austrian` (1.00, 1) | ✅ | ✅ |  |
| R04_nationality | Nationality | `Austrian` | 1 | `Austrian` (0.87) | 0.62 | 0.05 | `Austrian` (1.00, 1) | ✅ | ✅ |  |
| R05_about | About | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (0.98) | 0.52 | 0.84 | ∅ (none) (0.18, 254) † | ❌ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R05_about | About | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (0.99) | 0.50 | 0.82 | ∅ (none) (0.14, 254) † | ❌ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R06_country ⚠ | Country of residence | `Austria` | 0 | `Senior Data Engineer, Voe…` (0.29) | 0.38 | 0.05 | – | ❌ | ❌ ∅ (none) |  |
| R06_country ⚠ | Country of residence | `Austria` | 1 | `Senior Data Engineer, Voe…` (0.30) | 0.29 | 0.05 | – | ❌ | ❌ ∅ (none) |  |
| R07_linkedin_NEG | LinkedIn URL | ∅ (none) | 0 | ∅ (none) (1.00) | 0.16 | 0.05 | – | ✅ | ✅ |  |
| R07_linkedin_NEG | LinkedIn URL | ∅ (none) | 1 | ∅ (none) (1.00) | 0.13 | 0.05 | – | ✅ | ✅ |  |
| R08_summary | Profile summary | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (1.00) | 0.29 | 0.87 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R08_summary | Profile summary | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (1.00) | 0.27 | 0.86 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R09_biography ⚠ | Biography | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (0.93) | 0.39 | 0.80 | – | ❌ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R09_biography ⚠ | Biography | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (0.96) | 0.42 | 0.79 | – | ❌ | ❌ ∅ (none) |  |
| R10_description ⚠ | Description | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (0.99) | 0.33 | 0.90 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R10_description ⚠ | Description | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (0.98) | 0.34 | 0.92 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| O01_email | Email used for the order | `wren.castellan@example.net` | 0 | `Order 4711 for wren.caste…` (0.93) | 0.91 | 0.04 | `wren.castellan@example.net` (0.99, 10) | ✅ | ✅ |  |
| O01_email | Email used for the order | `wren.castellan@example.net` | 1 | `Order 4711 for wren.caste…` (0.94) | 0.89 | 0.05 | `wren.castellan@example.net` (0.99, 10) | ✅ | ✅ |  |
| O02_order_number | Order number | `4711` | 0 | `Order 4711 for wren.caste…` (0.86) | 0.93 | 0.05 | `4711` (0.97, 10) | ✅ | ✅ |  |
| O02_order_number | Order number | `4711` | 1 | `Order 4711 for wren.caste…` (0.88) | 0.94 | 0.04 | `4711` (0.97, 10) | ✅ | ✅ |  |
| O03_recipient | Recipient name | `Lise Adler` | 0 | `Lise Adler, Hauptstr. 5, …` (0.67) | 0.95 | 0.04 | `Lise Adler` (1.00, 21) | ✅ | ✅ |  |
| O03_recipient | Recipient name | `Lise Adler` | 1 | `Lise Adler, Hauptstr. 5, …` (0.65) | 0.94 | 0.04 | `Lise Adler` (1.00, 21) | ✅ | ✅ |  |
| O04_street | Street | `Hauptstr. 5` | 0 | `Lise Adler, Hauptstr. 5, …` (0.63) | 0.95 | 0.04 | `Hauptstr. 5` (0.99, 21) | ✅ | ✅ |  |
| O04_street | Street | `Hauptstr. 5` | 1 | `Lise Adler, Hauptstr. 5, …` (0.63) | 0.94 | 0.04 | `Hauptstr. 5` (0.99, 21) | ✅ | ✅ |  |
| O05_postal_code | Postal code | `4020` | 0 | `Lise Adler, Hauptstr. 5, …` (0.56) | 0.95 | 0.04 | `4020` (1.00, 21) | ✅ | ✅ |  |
| O05_postal_code | Postal code | `4020` | 1 | `Lise Adler, Hauptstr. 5, …` (0.52) | 0.94 | 0.04 | `4020` (1.00, 21) | ✅ | ✅ |  |
| O06_city | City | `Linz` | 0 | `Lise Adler, Hauptstr. 5, …` (0.75) | 0.96 | 0.04 | `Linz` (1.00, 21) | ✅ | ✅ |  |
| O06_city | City | `Linz` | 1 | `Lise Adler, Hauptstr. 5, …` (0.79) | 0.94 | 0.04 | `Linz` (1.00, 21) | ✅ | ✅ |  |
| O07_amount ⚠ | Amount paid | `129,90` | 0 | `Total EUR 129,90` (0.98) | 0.93 | 0.05 | `129,90` (0.56, 10) | ✅ | ✅ |  |
| O07_amount ⚠ | Amount paid | `129,90` | 1 | `Total EUR 129,90` (0.98) | 0.91 | 0.05 | `129,90` (0.52, 10) | ✅ | ✅ |  |
| O08_tracking | Tracking number of the original parcel | `00340434161234567890` | 0 | `Tracking DHL 003404341612…` (0.97) | 0.97 | 0.06 | `00340434161234567890` (0.92, 6) | ✅ | ✅ |  |
| O08_tracking | Tracking number of the original parcel | `00340434161234567890` | 1 | `Tracking DHL 003404341612…` (0.96) | 0.97 | 0.05 | `00340434161234567890` (0.95, 6) | ✅ | ✅ |  |
| O09_coupon_NEG | Coupon code (if any) | ∅ (none) | 0 | ∅ (none) (0.97) | 0.37 | 0.06 | – | ✅ | ✅ |  |
| O09_coupon_NEG | Coupon code (if any) | ∅ (none) | 1 | ∅ (none) (0.95) | 0.33 | 0.05 | – | ✅ | ✅ |  |
| B01_handle | Instagram handle | `@mira_h` | 0 | `I post new glazes and kil…` (0.58) | 0.82 | 0.06 | `@mira_h` (0.99, 101) | ✅ | ✅ |  |
| B01_handle | Instagram handle | `@mira_h` | 1 | `I post new glazes and kil…` (0.65) | 0.80 | 0.05 | `@mira_h` (0.99, 101) | ✅ | ✅ |  |
| B02_city | City | `Innsbruck` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.84) | 0.91 | 0.05 | `Innsbruck.` (0.84, 113) | ❌ | ❌ `Innsbruck.` |  |
| B02_city | City | `Innsbruck` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.84) | 0.89 | 0.05 | `Innsbruck.` (0.86, 113) | ❌ | ❌ `Innsbruck.` |  |
| B03_bio ⚠ | Bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.65) | 0.33 | 0.86 | – | ✅ | ✅ |  |
| B03_bio ⚠ | Bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.75) | 0.33 | 0.87 | – | ✅ | ✅ |  |
| B04_birth_year | Birth year | `1994` | 0 | `Born in 1994 and raised o…` (0.70) | 0.92 | 0.04 | `1994` (1.00, 149) | ✅ | ✅ |  |
| B04_birth_year | Birth year | `1994` | 1 | `Born in 1994 and raised o…` (0.68) | 0.92 | 0.04 | `1994` (1.00, 149) | ✅ | ✅ |  |
| B05_phone_NEG | Phone | ∅ (none) | 0 | ∅ (none) (0.96) | 0.13 | 0.05 | – | ✅ | ✅ |  |
| B05_phone_NEG | Phone | ∅ (none) | 1 | ∅ (none) (0.98) | 0.16 | 0.05 | – | ✅ | ✅ |  |
| B06_biography ⚠ | Biography | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.62) | 0.39 | 0.74 | – | ❌ | ❌ ∅ (none) |  |
| B06_biography ⚠ | Biography | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.62) | 0.37 | 0.71 | – | ❌ | ❌ ∅ (none) |  |
| B07_about_me ⚠ | About me | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.64) | 0.31 | 0.87 | – | ✅ | ✅ |  |
| B07_about_me ⚠ | About me | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.63) | 0.35 | 0.88 | – | ✅ | ✅ |  |
| B08_short_bio ⚠ | Short bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.53) | 0.46 | 0.25 | – | ✅ | ✅ |  |
| B08_short_bio ⚠ | Short bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.54) | 0.52 | 0.22 | `a ceramicist working out …` (0.22, 254) | ❌ | ❌ `a ceramicist working …` |  |
| T01_email_two_lines ⚠ | Email | `wren.castellan@example.net` | 0 | `Ticket 4711 wren.castella…` (0.54) | 0.94 | 0.11 | `wren.castellan@example.net` (0.85, 6) | ✅ | ✅ |  |
| T01_email_two_lines ⚠ | Email | `wren.castellan@example.net` | 1 | `Ticket 4711 wren.castella…` (0.42) | 0.94 | 0.08 | `wren.castellan@example.net` (0.67, 20) | ✅ | ✅ | 1 |
| C01_cover_letter ⚠ | Cover letter | `I am writing to apply for the Jun…` | 0 | `Dear Ms Hofer,⏎⏎I am writ…` (0.69) | 0.47 | 0.97 | – | ✅ | ✅ |  |
| C01_cover_letter ⚠ | Cover letter | `I am writing to apply for the Jun…` | 1 | `Dear Ms Hofer,⏎⏎I am writ…` (0.74) | 0.43 | 0.97 | – | ✅ | ✅ |  |
| C02_motivation | Motivation | `What draws me to Grünraum is your…` | 0 | `What draws me to Grünraum…` (0.92) | 0.47 | 0.59 | – | ✅ | ✅ |  |
| C02_motivation | Motivation | `What draws me to Grünraum is your…` | 1 | `What draws me to Grünraum…` (0.92) | 0.38 | 0.60 | – | ✅ | ✅ |  |
| C03_availability | Availability | `I can start on 1 December 2026 an…` | 0 | `I can start on 1 December…` (0.66) | 0.62 | 0.22 | `1 December 2026 and am av…` (0.78, 125) | ❌ | ❌ `1 December 2026 and a…` |  |
| C03_availability | Availability | `I can start on 1 December 2026 an…` | 1 | `I can start on 1 December…` (0.68) | 0.66 | 0.31 | `1 December 2026 and am av…` (0.82, 125) | ❌ | ❌ `1 December 2026 and a…` |  |
| C04_name | Name | `Theo Brandner` | 0 | `Theo Brandner` (0.97) | 0.64 | 0.43 | `Theo Brandner` (1.00, 3) | ✅ | ✅ |  |
| C04_name | Name | `Theo Brandner` | 1 | `Theo Brandner` (0.98) | 0.62 | 0.51 | `Theo Brandner` (1.00, 3) | ✅ | ✅ |  |
| C05_notes_freetext ⚠ | Notes | `Dear Ms Hofer,⏎⏎I am writing to a…` | 0 | ∅ (none) (0.55) | 0.35 | 0.88 | – | ❌ | ✅ |  |
| C05_notes_freetext ⚠ | Notes | `Dear Ms Hofer,⏎⏎I am writing to a…` | 1 | ∅ (none) (0.50) | 0.28 | 0.87 | – | ❌ | ✅ |  |

⚠ = borderline cell (see fixtures). † = stage 2 would not run in production (free_text override).


## Files

- `fixtures.py`: items, forms and cells.
- `spans.py`: Candidates, same-type detection and spans.
- `run.py`: J, tuning, J′ and the shelved `extend` command.
- `stage3.py`: stage 3.
- `l_rescue.py`: Engine L.
- `analyze.py` → `results/report.md`: the full per-cell table and every section above, generated from the log.
- `results/raw.jsonl`: every request and response, verbatim.
