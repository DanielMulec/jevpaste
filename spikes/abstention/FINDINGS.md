# Spike: abstention — can Jev's probabilities separate auto-insert / chooser / no-match?

Throwaway spike for [Choose Jev context and excerpt-selection semantics](https://github.com/DanielMulec/jevpaste/issues/7).
No product decision is taken here; everything below is data for the parent.

Evidence class is marked per statement: **[measured]** = observed in the logged runs,
**[inference]** = reasoning on top of those numbers.

- Endpoint: `POST https://ai-gateway.vercel.sh/v1/evaluate`, `model: typesafe-ai/jev`.
  Response `model` field echoes `typesafe-ai/jev`; no version string is returned **[measured]**.
- Run date 2026-09-21. **132 successful billed calls** (129 logged in `results/raw.jsonl`
  + 3 unlogged smoke calls). Reported `marketCost` totals **$0.00538** over the 129 logged
  calls (mean $0.000042/call); billed `cost` is `0` (free-tier credit) **[measured]**.
- Scripts: `sources.py` (documents), `candidates.py` (local excerpt derivation),
  `jev.py` (stdlib client), `run.py` (protocol), `analyze.py` (`python3 analyze.py`).

## Setup

Source documents are reconstructed from the demo résumé in `README.md` plus three
variants and two unrelated documents. Candidates are derived **locally** by a
deliberately generic extractor (regex atoms, whole lines, sentences, capitalised runs),
capped at 20 options; every option is an exact contiguous substring of the source.

State sent per call: `{target_field: {form_title, section, label, placeholder}, source_document: <text>}`.

Four questions are batched in one call, then one follow-up call scores the winner:

| question | type | purpose |
| --- | --- | --- |
| `choice_plain` | choice over N candidates | baseline, no abstention affordance |
| `choice_none` | same + `none_of_these` option | mechanism (i) |
| `gate_pos` | boolean "does the document contain the value for this field?" | mechanism (ii) |
| `gate_neg` | boolean, inverted phrasing | coherence check |
| `fit_score` | score 0–3 on the winner of `choice_plain` | secondary gate |

12 cases × 5 repeats. Ground truth assigned before the calls: `exact` (one right answer),
`ambiguous` (several plausible by construction), `no_match` (nothing belongs in the field).

| case | source | target | truth |
| --- | --- | --- | --- |
| C1/C2/C3 | résumé | Email address / Full name / Current company | exact |
| F | résumé | Current location (nested spans "San Francisco" vs "San Francisco, CA") | exact |
| A | résumé with 3 emails | Email address | ambiguous |
| A2 | résumé with 2 peer institutional emails | Email address | ambiguous |
| E1/E2 | email header, two people | Full name / Email address | ambiguous |
| B1 | résumé with the location line removed | Postal address | no_match |
| B2 | résumé (has "San Francisco, CA") | Postal address | no_match (near miss) |
| D1/D2 | recipe paragraph | Full name / Email address | no_match |

## Measured results

`p1` = highest probability in `choice_plain`; `p_none` = probability mass on
`none_of_these` in `choice_none`; `conf_*` = the model's own `confidence` field;
`score` = 0–3 fit of the `choice_plain` winner. Ranges are min–max over 5 repeats.

```
case                 top pick (all reps)      p1          conf_plain  conf_none   gate+       score       p_none
C1_email_control     marcus@anything.com      1.00        1.00        1.00        0.97        2.99        0.00
C2_name_control      Marcus Lowe              1.00        1.00        1.00        0.97        2.99        0.00
C3_company_soft      Skydive                  0.99-1.00   0.99        0.99        0.93-0.94   2.90-2.95   0.00
F_location_nested    San Francisco, CA        1.00        1.00        1.00        0.97        2.99        0.00
A_email_three        marcus@anything.com      0.91-0.95   0.91-0.94   0.72-0.77   0.80-0.82   2.75-2.77   0.18-0.22
A2_email_two_peer    m.lowe@skydive.com       0.97-0.98   0.96-0.97   0.87-0.89   0.78-0.80   2.82-2.84   0.08-0.10
E1_header_name       Marcus Lowe              0.97-0.98   0.97-0.98   0.96-0.97   0.90-0.92   2.98        0.01
E2_header_email      marcus@anything.com      0.97-0.99   0.96-0.98   0.94-0.96   0.90-0.93   2.92-2.95   0.02-0.03
B1_postal_absent     Massachusetts Institute  0.38-0.58   0.36-0.55   1.00        0.02        0.74-0.77   1.00
B2_postal_citystate  San Francisco, CA        0.99-1.00   0.99        0.49-0.56   0.17-0.24   1.49-1.63   0.52-0.59
D1_recipe_name       Slow Tomato Sauce        0.86-0.90   0.84-0.87   0.99        0.01-0.02   0.24-0.27   1.00
D2_recipe_email      Slow Tomato Sauce        0.73-0.77   0.70-0.76   1.00        0.01-0.02   0.22-0.23   1.00
```

The top pick never changed across repeats in any case **[measured]**. `choice_none`
selected `none_of_these` in exactly the four `no_match` cases (20/20 reps) and never in
the eight answerable cases (0/40 reps) **[measured]**.

### Separation by ground truth (20 reps per group)

```
signal      exact        ambiguous    no_match     no_match gap         exact|ambiguous gap
p1          0.99-1.00    0.91-0.99    0.38-1.00    overlap              overlap
conf_plain  0.99-1.00    0.91-0.98    0.36-0.99    overlap              0.98 < x < 0.99
conf_none   0.99-1.00    0.72-0.97    0.49-1.00    overlap              0.97 < x < 0.99
p_none      0.00-0.00    0.01-0.22    0.52-1.00    0.22 < x < 0.52      0.00 < x < 0.01
gate_pos    0.93-0.97    0.78-0.93    0.01-0.24    0.24 < x < 0.78      overlap
gate_neg    0.06-0.14    0.17-0.25    0.87-0.97    0.25 < x < 0.87      0.14 < x < 0.17*
score       2.90-2.99    2.75-2.98    0.22-1.63    1.63 < x < 2.75      overlap
```

\* the nominal `gate_neg` exact/ambiguous split is only 0.03 wide, inside the observed
repeat noise (≤ 0.07 on boolean answers), so it is not treated as a real separation.

### False-positive risk of the choice distribution alone (no `none_of_these`)

```
p1 >= 0.70 auto-inserts 15/20 no-match reps  (San Francisco, CA; Slow Tomato Sauce)
p1 >= 0.80 auto-inserts 10/20 no-match reps  (San Francisco, CA; Slow Tomato Sauce)
p1 >= 0.90 auto-inserts  6/20 no-match reps  (San Francisco, CA; Slow Tomato Sauce)
p1 >= 0.95 auto-inserts  5/20 no-match reps  (San Francisco, CA)
```

The worst case is B2: pasting the city/state line into a **Postal address** field at
`p1 = 0.99–1.00` and `conf_plain = 0.99` — maximum confidence on an answer the product
must not insert **[measured]**. An unrelated document (recipe) also yields
`p1 = 0.73–0.90` on "Slow Tomato Sauce" for Full name / Email address **[measured]**.

### Threshold bands that separate these cases (measured, not a decision)

Midpoints of the observed gaps, over 60 batch repeats:

| signal | no-match if | answerable if | separating gap observed |
| --- | --- | --- | --- |
| `p_none` | ≥ 0.37 | ≤ 0.22 | 0.22 … 0.52 |
| `gate_pos` | ≤ 0.51 | ≥ 0.78 | 0.24 … 0.78 |
| `fit_score` | ≤ 2.19 | ≥ 2.75 | 1.63 … 2.75 |

For the chooser band, the only signals that separated `exact` from `ambiguous` on this
set are `p_none` (0.00 vs ≥ 0.01) and `conf_none` (≥ 0.99 vs ≤ 0.97) — both at the edge
of the API's 2-decimal rounding **[measured]**. `p1`, `gate_pos` and `fit_score` overlap.

### Stability, latency, tokens

- Repeat-to-repeat spread over 5 calls: `gate_pos` ≤ 0.07, `p_none` ≤ 0.07,
  `conf_none` ≤ 0.07, `score` ≤ 0.14, `p1` ≤ 0.20 (the 0.20 is B1, the forced choice with
  no valid answer) **[measured]**.
- Latency (wall clock, HTTPS from this Mac, n = 129): overall median **449 ms**,
  p95 **699 ms**, max 7307 ms (single outlier; 1/129 calls > 1 s) **[measured]**.
  - batched 4-question call (n=60): median 442 ms, p90 605 ms, p95 699 ms.
  - single-question score call (n=60): median 448 ms, p95 695 ms, max 995 ms.
  - one question alone (n=9): median 547 ms.
  Per-call latency is essentially flat in question count on this workload **[measured]**.
- Tokens: batched 4-question call `inputTokens` median 1496 (max 1528), `outputTokens`
  median 442; score call 578 in / 18 out **[measured]**. Output tokens are non-zero and
  billed at $0 despite the catalog's `max_tokens: 0`.
- Free tier throttles: several HTTP 429 `rate_limit_exceeded` responses forced a 0.7 s
  inter-call pacing plus exponential backoff; throttled attempts were not billed **[measured]**.

### Jaggedness observed

- `gate_pos + gate_neg` ranges from 0.96 to 1.16 across cases (E2: 1.09–1.16) — the
  question and its negation do not sum to 1, as TypeSafe's docs warn **[measured]**.
- All `probabilities` are rounded to 2 decimals, so margins below 0.01 are invisible;
  `score` (e.g. 2.99 with a `{3: 1.0}` distribution) and `confidence` carry finer
  resolution than the distribution they are derived from **[measured]**.
- Asking the questions in one batched call vs one per call changed the answers by
  ≤ 0.03 on the three cases retested (C1, A, D1) — no batching interference **[measured]**.

## What surprised me

1. **Jev almost never expresses ambiguity as spread probability.** The three-email case
   still produced `p1 = 0.91–0.95`; two peer institutional emails produced 0.97; a
   two-person email header produced 0.97–0.99. Jev resolves ambiguity by document
   convention (the owner/sender/primary address) instead of hedging **[measured]**.
2. **The only spread observed came from a case with no valid answer at all** (B1,
   `p1 = 0.38–0.58`) — spread indicates "nothing fits", not "several fit" **[measured]**.
3. **Maximum confidence on a wrong-kind value.** `choice_plain` gave "San Francisco, CA"
   for Postal address at `p1 = 1.00` **[measured]**.
4. **Adding `none_of_these` cost nothing on the good cases.** `p_none` was exactly 0.00
   in all 20 `exact` reps: no false abstention, and the winner never changed **[measured]**.
5. **Nested overlapping spans are handled cleanly**: "San Francisco, CA" beat the
   substring "San Francisco" for Current location at p = 1.00 **[measured]**.

## Implications for the contract decision

1. **Abstention has to be asked for explicitly.** The choice distribution alone is not an
   abstention signal — it saturates at 1.00 on a value that must not be inserted, and a
   `p1 ≥ 0.7` rule would have inserted 15/20 no-match repeats. Both explicit mechanisms
   (`none_of_these` option, boolean gate) separated no-match with a wide margin
   (gap 0.22–0.52 and 0.24–0.78 respectively) **[measured]**.
2. **The two mechanisms are redundant on this set and are cheap to run together.** They
   fit in the same call as the choice, and per-call latency is flat in question count
   (median 442 ms for 4 questions) **[measured]**. The `fit_score` gate is the only signal
   that needs a *second* sequential call, because it names the chosen excerpt: that
   doubles round trips (≈ 890 ms median, ≈ 1.4 s at p95) and would breach the 1 s p95
   target recorded in issue #5 **[measured latency, inference about the budget]**.
3. **Detecting "several plausible" — the Candidate Chooser trigger — is not solved by
   these probabilities.** No signal separated exact from ambiguous by more than the
   2-decimal rounding step (`p_none` 0.00 vs 0.01; `conf_none` 0.99 vs 0.97), and Jev
   silently resolves exactly the cases the chooser exists for **[measured]**. Either the
   chooser is triggered by *local* evidence (e.g. several candidates of the same type as
   the field), or it needs a differently-shaped question than the ones tried here
   **[inference]**.
4. **Near-miss values are the dangerous class, and only an abstention question catches
   them.** B2 (city/state into Postal address) was caught by `p_none` (0.52–0.59),
   `gate_pos` (0.17–0.24) and `fit_score` (1.49–1.63), and missed by `p1`/`conf_plain`
   (0.99–1.00). Its signals also sit closest to the answerable band of all no-match
   cases, so the no-match threshold is set by near misses, not by unrelated text
   **[measured]**.

## Limitations

- 12 cases from one source family (a demo résumé, an email header, a recipe), English
  only, 5 repeats each. These are separation observations, not a calibration set.
- Question wording was not varied; abstention behaviour may be sensitive to it.
- No adversarial or prompt-injection content was tested (out of scope for this spike).
- The gateway does not return a Jev version string, so the numbers cannot be pinned to a
  model build; re-measure before relying on any threshold.
- Candidate derivation used one generic extractor; different candidate sets change the
  probability mass distribution and therefore the observed bands.

## Reproduce

```sh
set -a; . ~/.config/jevpaste/env; set +a   # AI_GATEWAY_API_KEY, never printed
cd spikes/abstention
python3 run.py main          # 12 cases x 5 repeats, 2 calls each (120 calls)
python3 run.py unbatched     # 9 single-question calls
python3 analyze.py           # tables above, from results/raw.jsonl, no API calls
```
