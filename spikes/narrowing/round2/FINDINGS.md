# Spike findings — choice-only Narrowing, round 2 (issue #49)

Brief: `docs/briefs/narrowing-spike-round2-brief.md` (on `main`). Branch `spike/narrowing` (never merged). **Data only —
no product decision.** Tags: **[measured]** = in `results/raw.jsonl`; **[inference]** = my reading of it.
Round-1 files (`../FINDINGS.md`, `../results/`) are untouched.

Three designs ran, each labelled below:
1. **`r2`** — frozen at GATE A; its matrix was **stopped by the supervisor after 29 run-0 pastes** (A04 confirm-step miss).
2. **Fix exploration L0–L4** (43 calls) on the later-step ("confirm") question.
3. **`r2b`** — `r2` with one **supervisor-approved change after GATE A** (GATE A2): at later steps the "unchanged"
   option is offered as an excerpt id like every other piece. **The `r2b` matrix carries the verdict.** During it, one
   implementation bug (full-text fallback did not re-split by size) broke N03; the supervisor approved the fix and an
   N03-only re-run (phase `matrix2-n03fix`).

## Verdict (`r2b`, both runs of every cell) [measured]

Round-1 cells = the 65 cells of round 1 (28+5 of them were tuned on, see below). Held-out = 18 new cells written and
committed (6f2d8ca) before any round-2 call, never used for tuning. Policy A = Narrowing alone; policy B = the place
choice decides "everything" → whole copy and "nothing" → No Suitable Match; "one part" → Narrowing's result.

| # | criterion | round-1 cells, A | round-1 cells, B | held-out, A | held-out, B |
|---|---|---|---|---|---|
| 1 | every positive cell hits | **FAIL** 71/74 (C03 ×2, C04 r0) | **FAIL** 71/74 (same) | PASS 18/18 | PASS 18/18 |
| 2 | every trap → No Suitable Match | PASS 12/12 | PASS 12/12 | PASS 4/4 | PASS 4/4 |
| 3 | chat/terminal/Notes → whole copy; About/Profile summary/Description → paragraph | **FAIL** 14/16 (R10 ×2) | **FAIL** 14/16 (R10 ×2) | PASS 6/6 | PASS 6/6 |
| 4 | chooser on two and three emails, nowhere else | PASS 4/4, no ask elsewhere | PASS 4/4 | PASS 6/6, no ask elsewhere (incl. H15 Mobile) | PASS 6/6 |
| 5 | every paste byte-exact | PASS 130/130 | PASS 130/130 | PASS 36/36 | PASS 36/36 |
| 6 | median < 2 s, nothing > 5 s | PASS median 1059 ms, p90 1586, max 3421 | PASS median 1052, max 3421 | PASS median 956, p90 1425, max 2237 | PASS 956 / 2237 |
| 7 | new cells | PASS: N01 `Graz` 2/2; N02 URL→chat 2/2; N03 300 lines `WINTER-4471-KQ` 2/2 (after the fix); N04 too big → HTTP 400 2/2 | **FAIL**: N02 → nothing 0/2 (place choice "nothing" 0.70 / 0.62) | PASS: H07, H08 URL→chat 4/4 | PASS 4/4 |

**Failing criteria: round-1 cells A: 1, 3 · round-1 cells B: 1, 3, 7 · held-out A: none · held-out B: none.**

Borderline cells (not gating for criterion 1): 20/24 under A (misses R10 ×2, B06 ×2), 21/24 under B. R10 is
borderline in the fixtures but is listed in criterion 3, where it gates.

## Every miss (`r2b`), with what Jev chose instead [measured]

Step notation: `pick (options/choices, p)`; place = the place choice's p(everything / one part / nothing).

| cell | run | policy | expected | pasted | steps | place |
|---|---|---|---|---|---|---|
| C03_availability | 0 | A, B | paragraph 3 (2 lines) | `I can start on 1 December 2026 and am available for interviews on any weekday afternoon.` (line 1 of it) | that line (62/3, 0.39) › keep (154, 0.70, speculative) | 0.27 / 0.72 / 0.01 |
| C03_availability | 1 | A, B | same | same | that line (63/3, 0.38) › keep (154, 0.69) | 0.20 / 0.79 / 0.01 |
| C04_name | 0 | A, B | `Theo Brandner` | the whole cover letter | everything (69/3, 0.44) | 0.18 / 0.81 / 0.01 |
| R10_description ⚠ | 0 | A, B | the About paragraph | the whole résumé | everything (255/3, 0.37); About paragraph 0.04 | 0.50 / 0.50 / 0.00 |
| R10_description ⚠ | 1 | A, B | same | same | everything (255/3, 0.30) | 0.50 / 0.50 / 0.00 |
| B06_biography ⚠ | 0 | A | paragraph 1 or the whole bio | No Suitable Match | nothing fits (61/2 follow-up, 0.38); whole bio 0.30 | 0.57 / 0.42 / 0.01 (B: whole bio ✅) |
| B06_biography ⚠ | 1 | A, B | same | No Suitable Match | nothing fits (255/2, 0.22); whole bio 0.21 | 0.47 / 0.52 / 0.01 |
| N02_url_chat | 0, 1 | B only | the URL | No Suitable Match (place "nothing" 0.70 / 0.62) | A: everything (235, 0.45 / 0.47) ✅ | 0.24 / 0.06 / 0.70; 0.33 / 0.05 / 0.62 |

C04 r1 hit (`Theo Brandner` 0.45, then keep 0.97): C04 flips between runs, as in exploration (0.34–0.64) [measured].

### Expectation questions for Daniel
- **C03_availability** (scored as a miss): the fixture expects paragraph 3 = `I can start on 1 December 2026 and am available
  for interviews on any weekday afternoon.⏎I am happy to relocate for the role.`. Jev takes the first line only (step 1
  p 0.39 / 0.38, then keeps it at 0.70 / 0.69) and in both runs. The second line is not about availability.
- **R10_description** (borderline in the fixtures, gating in criterion 3): "Description — What do you do, for whom, and
  how do you work?" on a freelance listing; Jev pastes the whole résumé (0.37 / 0.30; place choice 0.50 / 0.50).
- **B06_biography** (borderline): "Biography — Printed in the programme. Third person reads best, around 80 words." The
  bio is first person; Jev leans to "nothing fits" (0.38 / 0.22 vs the whole bio 0.30 / 0.21).
- **A12_strasse_hnr** hits in both runs now, but step 1 is close: `Prankergasse 77` 0.55 / 0.60 vs
  `Prankergasse 77⏎Top 11`. In exploration Jev took `Prankergasse 77⏎Top 11` at step 1 in most screens (0.64–0.86) and
  then narrowed at step 2 [measured]. Whether `Top 11` belongs to "Straße und Hausnummer" when the form has no separate
  field for it is arguably an Austrian-address judgement [inference].

## Design `r2b` (the verdict design)

**Cutting (D1)** — character classes only, no meaning rules (`r2.py` `children2`, round-1 `cuts.py` unchanged):
- Coarse children = round 1's unflattened children: a piece of ≥ 2 lines → every run of consecutive lines + 4 edge cuts
  (or runs of blocks of b lines + every single line when too big); a one-line piece → every token run + edge cuts (or
  blocks when too big); one token → every substring; one character → final, no call.
- Fine children = every run of 1..8 tokens inside one line (token = maximal letter/digit run or one other non-space
  character). Grouping only: every substring stays reachable through the coarse children (`python3 r2.py reach r2b`:
  0 unreachable over all 82 cells that fit). Fine runs are dropped only when the set exceeds 12 choices or the size
  budget (N03, N04).
- Offline [measured]: the expected excerpt is on offer at step 1 for 55/56 round-1 positives (round-1 design: 48/56).

**Choices** — ≤ 252 pieces + unchanged + nothing fits + ask the user per choice (255 options). Layout "cont": the coarse
pieces are repeated in every choice and the fine pieces spread over the choices (document order when the coarse set
> 126 pieces). Several choices → one follow-up choice (same wording) over unchanged + every piece with p ≥ 0.01 in any
choice + nothing + ask; no follow-up when every choice picks the same non-piece option. **Speculative fan-out**
(TypeSafe's documented pattern, `docs.typesafe.ai/patterns/fan-out`): the follow-up request also carries the next-step
question for the 3 most likely carried pieces whose children fit in one choice; if the follow-up picks one of them, its
next step is already answered (33 times in the matrix, one call saved each).

**Option form (D2)** — id-only options (`null` descriptions); every piece's text once in `state.excerpts` {id: text};
state = `{source_document, target_context, excerpts}`. At later steps the "unchanged" option is itself the excerpt id of
`current_piece` (the `r2b` change). Full-text fallback when the size model says the excerpts would overfill the state
(K01, N03, N04): options carry their text, the later-step "unchanged" option's description is
`{"option": "`current_piece` as it is, nothing cut away.", "text": <current_piece>}`, and (after the fix) the choices
are re-split by the full-text size budget. In the matrix: 279 requests ids, 8 full.

**Decision** — argmax of the deciding choice; byte-exact check at every step; chooser list = every option with p > 0
except nothing/ask, most likely first; outer line breaks stripped on every whole-copy paste.

**Place choice (D4, measurement only)** — a separate choice in the step-1 request.

### Every wording, verbatim (unchanged from GATE A; the supervisor checked them for field/place vocabulary)

Step 1 `instructions`:
> The user copied `source_document` and pressed paste. `target_context` describes the place where the text cursor is, and what surrounds that place. One option is everything that was copied, as it is. Every other excerpt option is the id of an exact excerpt cut from `source_document`; `excerpts` gives the text of each id, character for character. Choose what will be pasted at the text cursor. If that place asks for one particular thing, choose the option that is exactly that thing, with nothing missing and nothing extra; only if no option is exactly that, choose the option that contains all of it with the least extra text. If that place does not ask for one particular thing, choose everything that was copied. If two or more different excerpts are each exactly the thing that place asks for and nothing says which one is meant, choose `ask_user` instead of one of them.

Later steps: `instructions = {"current_piece": P, "question": …}` with question:
> The user copied `source_document` and pressed paste. `target_context` describes the place where the text cursor is, and what surrounds that place. `current_piece` is an exact excerpt of `source_document`. One option is `current_piece` kept as it is. Every other excerpt option is the id of a smaller exact excerpt cut from `current_piece`; `excerpts` gives the text of each id, character for character. Choose what will be pasted at the text cursor. If that place asks for one particular thing, choose the option that is exactly that thing, with nothing missing and nothing extra; only if no option is exactly that, choose the option that contains all of it with the least extra text. If that place does not ask for one particular thing, choose `current_piece` as it is. If two or more different excerpts are each exactly the thing that place asks for and nothing says which one is meant, choose `ask_user` instead of one of them.

Full-text fallback replaces the option sentence with: "Every other excerpt option is an exact excerpt cut from
`source_document`; its description is that excerpt, character for character." (later: "…a smaller exact excerpt cut
from `current_piece`; its description is…").

Follow-up choice: the wording of the step it follows.

`everything` (step 1, key `everything`):
> Everything that was copied, as it is: all of `source_document`, nothing cut away.

Unchanged at later steps (key = the excerpt id of `current_piece`):
> `current_piece` as it is, nothing cut away.

`nothing_fits`:
> That place asks for one particular thing, and no part of `source_document` is that thing.

`ask_user`:
> That place asks for one particular thing, two or more different excerpts of `source_document` are each exactly that thing, and nothing says which one is meant; the user has to pick.

Place choice (P3), `instructions`:
> The user copied `source_document` and pressed paste. `target_context` describes the place where the text cursor is, and what surrounds that place. What will be pasted at the text cursor?

options — `everything`: "Everything that was copied, as it is: that place does not ask for one particular part of
it." · `one_part`: "One part of what was copied: that place asks for one particular thing, and `source_document`
contains it." · `nothing`: "Nothing of what was copied: that place asks for one particular thing, and
`source_document` does not contain it."

## Latency, calls, cost (`r2b` matrix) [measured]

- Per paste = sum over steps of the step's call (one request per step; 429/503 waits excluded):
  - policy A, all: n=164 (N04 excluded), median 1028 ms, p90 1564 ms, max 3421 ms (N03, 4 calls).
  - round-1 cells: median 1059 ms, p90 1586 ms; held-out: median 956 ms, p90 1425 ms, max 2237 ms.
  - policy B: median 1023 ms (pastes where the place choice decides need only the step-1 request).
  - by calls: 1 call n=55 median 637 ms; 2 calls n=99 median 1162 ms (max 1894); 3 calls n=8 median 1818 ms (max
    2731); 4 calls n=2 (N03) 3221 / 3421 ms.
- Per call: warm n=281 median 581 ms, p90 834 ms, max 1404 ms; cold (first call of a process) 818, 499, 1381, 1182 ms.
- **No single call over 3 s in the `r2b` matrix.** The only one in round 2: exploration, B02_city follow-up (design
  `r2`), 8206 ms, 4 questions, 21,667 request bytes, 9,932 input tokens, ids form, no 429 [measured]. The same request
  shape ran 0.5–1.0 s elsewhere; not reproduced [inference: a slow upstream attempt].
- Calls per paste (A): mean 1.74 (round-1 cells 1.78, held-out 1.58); 1×57, 2×99, 3×8, 4×2 (both N03). Policy B mean 1.73.
- **Free → paid tier** (Daniel, ~17:05): last matrix2 call with a 429 wait at 17:18:01 (H10 r0), every call from
  17:18:02 (H11 r0) on had none. Before: 128 calls, 39 × 429 (1,787 s) and 67 × 503 (402 s). After: 163 calls, 0 waits.
  Per-paste latency excludes waits in both periods.
- Billed calls round 2: **526** (explore 140, frozen `r2` matrix 58, fix exploration 43, `r2b` matrix 277, N03 re-run 8;
  budget 700, stop-and-ask 650). Spike total with round 1 (184): **710** (≤ 900). Unbilled: 6 × HTTP 400 in matrix2
  (N03 ×4 before the fix, N04 ×2 as designed). Round-2 input tokens 4.82 M; Gateway cost **$0.2025**.

### N03 fix (supervisor-approved during matrix2)
N03 failed 4 times (runs 0 and 1, each + one retry) with HTTP 400 `max_tokens_exceeded`, unbilled: the full-text
fallback reused the id-form split (by count, 252 + 50) instead of re-splitting by the full-text size budget (151 + 151),
so one question carried 255 full-text log options (state + question est. 38.9k > 32k). Fix: re-split on fallback; the
offline check over all cells showed only N03 changes (K01's fallback split is identical). Re-run (phase
`matrix2-n03fix`): `WINTER-4471-KQ` in both runs, 4 calls, 3421 / 3221 ms.

## Table 1 — design `r2` (frozen at GATE A), matrix stopped after 29 run-0 pastes [measured]

Why stopped: A04_hausnummer failed criterion 1 (step 2 on `77` picked `7` 0.54 over keep), and keep at the confirm
step was systematically weak (S01 0.54, S02 0.64, A05 0.58, A07 0.72; round 1 ≈ 0.99). The held-out cells had not run
(run-0 order puts them last). A 28/29, B 27/29 (B also misses R06: place "nothing" 0.49).

| cell | A | B | pasted | calls | ms | steps |
|---|---|---|---|---|---|---|
| A01_vorname | ✅ | ✅ | `Mira` | 2 | 1787 | `Mira` (115, 0.89) › keep (12, 0.95) |
| A02_nachname | ✅ | ✅ | `Holzner` | 2 | 946 | `Holzner` (115, 0.93) › keep (30, 0.92) |
| A03_strasse | ✅ | ✅ | `Prankergasse` | 3 | 1796 | `Prankergasse 77` (115, 0.47) › `Prankergasse` (17, 0.75) › keep (76, 0.69) |
| A04_hausnummer | ❌ | ❌ | `7` | 2 | 1093 | `77` (115, 0.86) › `7` (4, 0.54) |
| A05_adresszusatz | ✅ | ✅ | `Top 11` | 2 | 1027 | `Top 11` (115, 0.82) › keep (8, 0.58) |
| A06_plz | ✅ | ✅ | `8020` | 2 | 1172 | `8020` (115, 0.98) › keep (11, 0.99) |
| A07_ort | ✅ | ✅ | `Graz` | 2 | 1354 | `Graz` (115, 0.97) › keep (12, 0.72) |
| A08_land | ✅ | ✅ | `Österreich` | 2 | 908 | `Österreich` (115, 0.97) › keep (55, 0.88) |
| A09_email | ✅ | ✅ | `mira.holzner@example.org` | 2 | 1040 | `mira.holzner@example.o…` (115, 0.93) › keep (34, 0.99) |
| A10_website | ✅ | ✅ | `https://www.miraholzner.example` | 2 | 1205 | `https://www.miraholzne…` (115, 0.89) › keep (55, 0.89) |
| A11_telefon | ✅ | ✅ | `06608405534` | 2 | 1150 | `06608405534` (115, 0.97) › keep (63, 0.75) |
| A12_strasse_hnr | ✅ | ✅ | `Prankergasse 77` | 2 | 1600 | `Prankergasse 77` (115, 0.62) › keep (17, 0.92) |
| A13_passwort_NEG | ✅ | ✅ | nothing | 1 | 816 | nothing_fits (115, 0.94) |
| A14_fax_NEG | ✅ | ✅ | nothing | 1 | 718 | nothing_fits (115, 0.52) |
| S01_first_name | ✅ | ✅ | `Jonas` | 2 | 1329 | `Jonas` (186, 0.92) › keep (17, 0.54) |
| S02_last_name | ✅ | ✅ | `Prell` | 2 | 1083 | `Prell` (186, 0.90) › keep (16, 0.64) |
| S03_job_title | ✅ | ✅ | `Product Lead` | 2 | 1092 | `Product Lead` (186, 0.92) › keep (14, 0.97) |
| S04_phone | ✅ | ✅ | `+43 1 2345678` | 3 | 2003 | `Phone +43 1 2345678` (186, 0.79) › `+43 1 2345678` (27, 0.64) › keep (18, 0.87) |
| S05_mobile | ✅ | ✅ | `+43 660 1112233` | 2 | 1224 | `+43 660 1112233` (186, 0.93) › keep (18, 0.90) |
| S06_email | ✅ | ✅ | `jonas.prell@example.com` | 2 | 1055 | `jonas.prell@example.co…` (186, 0.97) › keep (35, 0.99) |
| S07_website | ✅ | ✅ | `www.prell.example` | 2 | 1330 | `www.prell.example` (186, 0.95) › keep (24, 0.86) |
| S08_iban | ✅ | ✅ | `AT61 1904 3002 3457 3201` | 3 | 1809 | `IBAN AT61 1904 3002 34…` (186, 0.85) › `AT61 1904 3002 3457 32…` (29, 0.89) › keep (23, 0.96) |
| S09_fax_NEG | ✅ | ✅ | nothing | 1 | 643 | nothing_fits (186, 0.91) |
| R01_full_name | ✅ | ✅ | `Anna Reisinger` | 2 | 1275 | `Anna Reisinger` (7/3, 0.94) › keep (16, 0.96, spec) |
| R02_birthdate | ✅ | ✅ | `14 March 1991` | 2 | 1538 | `14 March 1991` (53/3, 0.65) › keep (12, 0.93, spec) |
| R03_birthplace | ✅ | ✅ | `Linz` | 2 | 1430 | `Linz` (25/3, 0.95) › keep (12, 0.98, spec) |
| R04_nationality | ✅ | ✅ | `Austrian` | 2 | 1586 | `Austrian` (22/3, 0.83) › keep (38, 0.93, spec) |
| R05_about | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1306 | `Data engineer with eig…` (72/3, 0.47) › keep (255, 0.85, spec) |
| R06_country | ✅ | ❌ | `Austria` | 2 | 1413 | `Austria` (60/3, 0.75) › keep (30, 0.92, spec) |

## Table 2 — fix exploration L0–L4 (43 calls, phase `fix`, round-1 cells only) [measured]

Replays of the recorded later-step questions; step 1 identical to `r2` in every variant. keep p shown; `→` = the pick
when it was not keep. **L0** = `r2` as frozen. **L1** = the unchanged option's description carries the text
(`{"option": …, "text": P}`). **L2** = the unchanged option is the excerpt id of `current_piece` (its text in
`excerpts`, description unchanged) — **adopted as `r2b`**. **L3** = later wording "…with nothing missing and nothing
extra: `current_piece` as it is when it already is exactly that thing; only if…" (not adopted). **L4** = L2 + L3.
"all five (confounded)": the five variants in one request, so `current_piece` sat in `excerpts` for every variant —
which alone lifted L0 on A04 from 0.52 to 0.95, the clue that the option form, not the wording, was the cause.

| cell | piece | variants in the request | L0 | L1 | L2 | L3 | L4 |
|---|---|---|---|---|---|---|---|
| A04_hausnummer | `77` | all five (confounded) | 0.95 | 0.95 | 0.96 | 0.96 | 0.96 |
| S01_first_name | `Jonas` | all five (confounded) | 0.97 | 0.98 | 0.99 | 0.99 | 1.00 |
| S02_last_name | `Prell` | all five (confounded) | 0.97 | 0.98 | 0.96 | 0.98 | 0.98 |
| A05_adresszusatz | `Top 11` | all five (confounded) | 0.71 | 0.71 | 0.79 | 0.75 | 0.85 |
| A07_ort | `Graz` | all five (confounded) | 0.99 | 0.99 | 1.00 | 1.00 | 1.00 |
| S04_phone | `Phone +43 1 2345678` | all five (confounded) | 0.04 → `+43 1 2345678` 0.95 | 0.02 → `+43 1 2345678` 0.96 | 0.05 → `+43 1 2345678` 0.93 | 0.06 → `+43 1 2345678` 0.92 | 0.07 → `+43 1 2345678` 0.90 |
| S04_phone | `+43 1 2345678` | all five (confounded) | 0.84 | 0.89 | 0.91 | 0.90 | 0.93 |
| A03_strasse | `Prankergasse 77` | all five (confounded) | 0.17 → `Prankergasse` 0.76 | 0.14 → `Prankergasse` 0.79 | 0.08 → `Prankergasse` 0.85 | 0.16 → `Prankergasse` 0.78 | 0.10 → `Prankergasse` 0.81 |
| A03_strasse | `Prankergasse` | all five (confounded) | 0.89 | 0.91 | 0.92 | 0.95 | 0.93 |
| A12_strasse_hnr | `Prankergasse 77` | all five (confounded) | 0.94 | 0.96 | 0.97 | 0.96 | 0.96 |
| O07_amount | `129,90` | all five (confounded) | 0.98 | 0.99 | 1.00 | 1.00 | 1.00 |
| B02_city | `Innsbruck` | all five (confounded) | 0.97 | 0.99 | 0.99 | 0.99 | 1.00 |
| C02_motivation | `What draws me to Grünrau…` | all five (confounded) | 0.44 | 0.67 | 0.46 | 0.66 | 0.62 |
| R05_about | `Data engineer with eight…` | all five (confounded) | 0.81 | 0.85 | 0.78 | 0.87 | 0.84 |
| A04_hausnummer | `77` | alone | 0.52 |  |  |  |  |
| S01_first_name | `Jonas` | alone | 0.92 |  |  |  |  |
| S02_last_name | `Prell` | alone | 0.73 |  |  |  |  |
| A05_adresszusatz | `Top 11` | alone | 0.54 |  |  |  |  |
| A07_ort | `Graz` | alone | 0.93 |  |  |  |  |
| A04_hausnummer | `77` | alone |  |  |  | 0.53 |  |
| S01_first_name | `Jonas` | alone |  |  |  | 0.95 |  |
| S02_last_name | `Prell` | alone |  |  |  | 0.77 |  |
| A05_adresszusatz | `Top 11` | alone |  |  |  | 0.70 |  |
| A07_ort | `Graz` | alone |  |  |  | 0.96 |  |
| A04_hausnummer | `77` | alone |  | 0.63 |  |  |  |
| S01_first_name | `Jonas` | alone |  | 0.97 |  |  |  |
| S02_last_name | `Prell` | alone |  | 0.93 |  |  |  |
| A05_adresszusatz | `Top 11` | alone |  | 0.59 |  |  |  |
| A07_ort | `Graz` | alone |  | 0.95 |  |  |  |
| A04_hausnummer | `77` | alone |  |  | 0.97 |  |  |
| S01_first_name | `Jonas` | alone |  |  | 0.99 |  |  |
| S02_last_name | `Prell` | alone |  |  | 1.00 |  |  |
| A05_adresszusatz | `Top 11` | alone |  |  | 0.88 |  |  |
| A07_ort | `Graz` | alone |  |  | 1.00 |  |  |
| A04_hausnummer | `77` | alone |  |  |  |  | 0.98 |
| S01_first_name | `Jonas` | alone |  |  |  |  | 1.00 |
| S02_last_name | `Prell` | alone |  |  |  |  | 1.00 |
| A05_adresszusatz | `Top 11` | alone |  |  |  |  | 0.65 |
| A07_ort | `Graz` | alone |  |  |  |  | 1.00 |
| C02_motivation | `What draws me to Grünrau…` | alone |  |  | 0.67 |  |  |
| R05_about | `Data engineer with eight…` | alone |  |  | 0.85 |  |  |
| A03_strasse | `Prankergasse 77` | alone |  |  | 0.21 → `Prankergasse` 0.75 |  |  |
| S04_phone | `Phone +43 1 2345678` | alone |  |  | 0.11 → `+43 1 2345678` 0.62 |  |  |

## Table 3 — the `r2b` matrix

Verdict and misses above. Per-paste table with every step (options, questions, pick, p, p(everything/keep),
p(nothing), p(ask)), forms used, speculative use and the place-choice probabilities of every paste:
`results/report.md` (generated by `analyze_r2.py`; policy B is re-scorable offline from the `place` field of every
`paste` row in `results/raw.jsonl`).

Watched cells [measured]: **C02_motivation** keep p at step 2 (paragraph, 2 choices) 0.69 / 0.65 → hit both runs.
**A05_adresszusatz** keep 0.86 / 0.89 → hit both runs. **C04** r0 everything 0.44 (miss), r1 `Theo Brandner` 0.45 →
keep 0.97 (hit).

## Exploration: the four levers (round-1 cells only; `results/explore.md` has every table) [measured]

Tuned-on cells (33, all round-1): A03 A04 A05 A07 A12 A13 B01 B02 B03 B05 C01 C02 C03 C04 C05 K01 N02 O07 O09 R03 R05
R06 R07 R08 S01 S02 S04 S05 T01 W01 W02 W03 W04. Held-out cells: none. Exploration 140 calls (budget 150) + fix 43.

**D3 wordings** (step-1 decision in screens; exact / on the path / miss). Questions in one request are evaluated
independently (TypeSafe docs), so variants ran as parallel questions over the same options.

| variant | what changed | exact / path / miss |
|---|---|---|
| V0 | round-1 wording verbatim (9 failure cells) | 3 / 1 / 5 |
| V1 | "exactly what belongs in that place" | 3 / 1 / 5 |
| V2 | + "nothing missing and nothing extra", containment only as a fallback, explicit ask sentence, "that place is for something that was not copied" | 23 / 3 / 9 |
| V3 | V2 + the everything option carries the copy's text | 5 / 1 / 3 |
| **V5** | "text cursor" preamble + "asks for one particular thing" (else everything) — **frozen** | **28 / 2 / 2** |
| V6 | V2 + "text cursor" preamble only | 22 / 2 / 3 |
| V7 | V5 + naming which `target_context` keys describe the place | 3 / 0 / 2 |

The ask sentence fixed K01 (three emails: `marcus@anything.com` 0.93 under V0 → ask 0.89 under V5) and T01; the
"particular thing" default fixed W01/W02/N02 (whole copy); W03 stayed close (0.44–0.47 vs the paragraph 0.29–0.32).

**D1 fineness and grouping**: short token runs at step 1 put the value on offer at step 1 for 55/56 positives (round-1
design 48/56) and fixed B02 (`Innsbruck` 0.97 at step 1 even with the round-1 wording; round 1: the whole line) and C02.
K = 4 / 6 / 8 / 10 → 51 / 53 / 55 / 55 offered, mean pieces 194 / 252 / 297 / 330. Layout "cont" vs document order, C04
under V5: ids+cont hit 2/2 in exploration (1/2 later in the `r2b` matrix); full+doc 1/4; full+cont 0/1 (small n).

**D2 option form**: id-only options did **not** save tokens — they cost ~20–35 % more input tokens than full-text
options on the same cell (e.g. B02 step 1 13,920 vs 10,575; C04 21,713 vs 16,336), because pieces are rarely repeated;
latency was the same (0.5–1.3 s per call). What id-only buys is cheap repetition of the containers in every choice
("cont"), and (after the fix) a confirm step with keep ≈ 0.97–1.00.

**D4 place choice**: argmax-correct against the expected class (whole → everything, trap → nothing, else one part):
P1 "What will the user paste there?" 33/55; P2 "What belongs in that place?" 31/55; **P3 (frozen)** 37/46; P4 (P3
question, plain options) 16/46. P3 fails on N02 (URL into ChatGPT → nothing 0.62–0.70), and is close on W03.

## Round-2 inferences [inference]
- The two remaining round-1 failures are whole-vs-part judgements on long multi-part copies with a form around them:
  C04 (cover letter into Name, the page has a "Cover letter — Paste your cover letter here" field) and R10 (résumé into
  a listing's Description). Both sit near 0.3–0.45, i.e. Jev is split, not wrong-and-sure. The held-out analogues
  (H01 Full name from a letter 0.95, H06 Company description → paragraph) passed.
- Policy B adds no hit over A and loses N02 (and one B06 run is rescued by it): the place choice judges a lone URL in a
  chat about something else as "nothing", while the Narrowing choice with "everything" on offer pastes it.
- Held-out pass rate (36/36 under A) is higher than on the tuned round-1 cells; the held-out set has no long
  multi-paragraph copy into a narrow field next to a whole-copy field, which is where the round-1 misses live.

## Files
`heldout.py` (18 held-out cells), `r2.py` (design, runner, screen, replay, reach), `explore_report.py` →
`results/explore.md`, `analyze_r2.py` → `results/report.md`, `results/raw.jsonl` (every request/response verbatim,
phases `explore`, `matrix` (frozen r2), `fix`, `matrix2`, `matrix2-n03fix`), `results/matrix.log`, `results/matrix2.log`,
`run_matrix.sh`.
