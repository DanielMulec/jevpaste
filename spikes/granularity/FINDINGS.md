# Spike: candidate granularity for Jev excerpt selection

Throwaway spike for [Choose Jev context and excerpt-selection semantics](https://github.com/DanielMulec/jevpaste/issues/7).
Question: **how should copied text be split into candidate excerpts?** No product decision is taken here.

- Branch `spike/jev-contract`, directory `spikes/granularity/` (scripts, sources, `results.jsonl`, raw response sample).
- Date: 2026-09-20. Model `typesafe-ai/jev` via `POST https://ai-gateway.vercel.sh/v1/evaluate`, one `choice` question per call.
- Spend: **128 billed evaluations** (126 logged experiment records + 1 smoke + 1 raw-response dump), plus 2 requests rejected with HTTP 400 (unbilled) and ~50 automatic retries after HTTP 429 (unbilled, `cost: "0"` on the free tier throughout).
- Evidence classes: **[measured]** = observed in this run; **[inference]** = reasoned from those observations.

## Setup

- Source document: the demo résumé reconstructed as plain text from `README.md` + `frames/frame_005.png` (`source_resume.txt`, 24 non-blank lines). Two variants: `source_resume_labeled.txt` (contact block rewritten as `Email: …`, `Location: …`, `X / Twitter: …`) and `source_resume_ambiguous.txt` (3 emails, 2 X profiles, 2 locations, 1 extra role).
- Targets: the 7 demo form fields. Target Context sent as `instructions` object (`form`, `section`, `label`, `placeholder`) plus a fixed question string. Expected values are the README's pasted values.
- Every candidate is verified locally to be an exact substring of the source before it is offered (the hard product rule), then deduplicated in document order.
- Strategies: `lines` (a), `paragraphs` (b, blank-line blocks), `field_like` (c, lines + `Label: value` lines split so the value is its own candidate), plus over-generating `dense` (lines + paragraphs + sentences + bullet bodies + comma/dash pieces) and `dense_words`/`dense_max` (adds word n-grams) for the >50 candidate test.
- Criteria arms: `text` (option description = candidate text, truncated at 255 chars), `index` (description = "Candidate excerpt number N in `candidate_excerpts`", candidates listed in `state`), `text_plus_list` (both), `list_only` (candidate text in criteria, **no** `copied_text` in state).

## Results (all [measured])

`exact` = chosen candidate string equals the README value; `cont` = chosen candidate contains it;
`reach` = how many of the 7 expected values the strategy can even produce.

```
document          strategy     arm             run    n  exact  cont   top1   marg   conf    ms    tok  reach
resume            lines        text            r1    24    7/7   7/7  1.000  1.000  1.000   437   1061   7/7
resume            lines        text            r2    24    7/7   7/7  1.000  1.000  1.000   438   1061   7/7
resume            lines        index           r1    24    7/7   7/7  1.000  1.000  1.000   450   1613   7/7
resume            lines        text_plus_list  r1    24    7/7   7/7  1.000  1.000  1.000   424   1467   7/7
resume            lines        list_only       r1    24    7/7   7/7  0.987  0.974  0.986   515   1270   7/7
resume            field_like   text            r1    24    7/7   7/7  1.000  1.000  1.000   436   1061   7/7
resume            field_like   text            r2    24    7/7   7/7  1.000  1.000  1.000   448   1061   7/7
resume            field_like   index           r1    24    7/7   7/7  1.000  1.000  1.000   446   1613   7/7
resume            paragraphs   text            r1     7    0/7   7/7  0.929  0.857  0.913   428    847   0/7
resume            paragraphs   index           r1     7    0/7   7/7  0.984  0.969  0.981  2278   1010   0/7
resume            dense        text            r1    47    7/7   7/7  0.993  0.989  0.993   459   1716   7/7
resume            dense_words  text            r1    95    7/7   7/7  0.994  0.990  0.993   472   2495   7/7
resume            dense_max    text            r1   255    7/7   7/7  0.997  0.994  0.994   431   5238   7/7
resume_labeled    lines        text            r1    24    4/7   7/7  1.000  1.000  1.000   497   1081   4/7
resume_labeled    field_like   text            r1    28    7/7   7/7  0.997  0.994  0.996   445   1163   7/7
resume_ambiguous  lines        text            r1    32    7/7   7/7  0.953  0.906  0.950   405   1269   7/7
resume_ambiguous  lines        list_only       r1    32    6/7   6/7  0.993  0.986  0.991   435   1550   7/7
resume_ambiguous  paragraphs   text            r1     8    0/7   7/7  0.940  0.883  0.927   479    964   0/7
```

Reproduce: `python3 run_probe.py summarize` (no calls) or `python3 run_probe.py run <experiment> <run_label>`.

### (a) lines vs (b) paragraphs vs (c) field-like

- **Line granularity: 7/7 exact, every arm, both runs.** Top-1 probability `1.00` and confidence `1.00` on all 14 line-level calls against the clean résumé.
- **Paragraph granularity: 0/7 exact, 7/7 containing.** This is structural, not a model error: none of the 7 expected values *is* a blank-line block, so the strategy's accuracy ceiling is 0. The chosen block always contained the expected value (the two arms disagree only on which block holds `Current role`: the header block vs the experience block, both contain `Co-founder & CEO`), and it was returned with confidence up to `1.00` while containing three other field values.
- **Field-like vs lines is a no-op on the demo résumé** (the PDF text has no `Label: value` lines, so the two strategies produce the identical 24 candidates). On the labeled variant the difference is decisive: `lines` 4/7 exact (it confidently returns `Email: marcus@anything.com`, `Location: San Francisco, CA`, `X / Twitter: https://x.com/marcus_lowe` at p=1.00), `field_like` 7/7. The label/value split costs 4 extra candidates and 82 input tokens.

### Criteria carrying text vs index-only reference

- **No accuracy or ranking difference on the clean résumé**: `text`, `index` and `text_plus_list` are all 7/7 with identical top-1 probabilities.
- **Cost difference is large**: `index` needs the candidate list inside `state` as well, so 1613 vs 1061 input tokens (+52%) for the same 24 candidates; `text_plus_list` 1467 (+38%).
- **[inference]** Index-only buys nothing here. The only situation where it could matter is candidates longer than the 255-character option-description limit (paragraph blocks already came within ~25 chars of it; no truncation was triggered in this run).

### >50 candidates

- 47, 95 and 255 candidates all scored **7/7 exact**. Mean top-1 fell only from 1.000 (24) to 0.993 (47), 0.994 (95), 0.997 (255).
- With 255 overlapping candidates (including every 1–4 word n-gram of short lines, e.g. `Marcus`, `Lowe`, `Marcus Lowe`), Jev still picked the full `Marcus Lowe` and the full summary sentence, not a fragment.
- **Hard ceiling confirmed by probe**: 256 options → `HTTP 400 … "Choice questions support at most 255 options"` (documented as 255; the error is a 400, not the 422 the TypeSafe docs suggest). Request is rejected outright, nothing billed.
- Cost/latency of over-generating is small: 24 → 1061 tokens (~$0.000045/call), 47 → 1716, 95 → 2495, 255 → 5238 (~$0.00022/call). No latency penalty was visible (255-candidate mean 431 ms vs 437 ms for 24).

### Ambiguity signal

- Clean résumé at line granularity: every top-1 is `1.00`, margin `1.00` — the signal is saturated and carries no information.
- Ambiguous résumé at line granularity: the signal appears exactly where it should. `Email address` → `marcus@anything.com` 0.69 vs `marcus.lowe@gmail.com` 0.31 (`press@skydive.com` 0.00), confidence 0.67; `X / Twitter profile` → 0.98 vs 0.02 for the company handle. All 7 still exact.
- Ambiguous résumé at paragraph granularity: the same document returns the whole contact block at top-1 `1.00`, confidence `1.00`, for `Email address`, `Current location` and `X / Twitter profile`. **Coarse candidates destroy the ambiguity signal** — the model is confident about a block, and the ambiguity inside the block is invisible.
- Dropping `copied_text` from the state (`list_only`) is the worst failure mode found: on the ambiguous résumé it picked `marcus.lowe@gmail.com` at p=0.97, confidence 0.96 — a **confident wrong answer** where the document-in-state arm correctly split 0.69/0.31.

### Mechanics worth recording

- Probabilities are returned for **every** option (126/126 calls) and are **rounded to 0.01**; observed values are exactly {0, 0.01…0.06, 0.09, 0.31, 0.36, 0.45, 0.55, 0.64, 0.69, 0.91, 0.94…1.00}.
- `confidence` (in `providerMetadata.typesafe.confidence`) equals top-1 in 110/126 calls and is slightly lower in 16 (e.g. top-1 0.55 → confidence 0.47; 0.69 → 0.67). It never exceeded top-1.
- **Determinism**: the 14 repeated calls (`lines`/`field_like` × 7 fields, run r1 vs r2) returned identical choices *and* identical probabilities.
- Latency over all 126 logged calls: min 357 ms, p50 425 ms, p95 632 ms, max 864 ms — excluding two 6.5 s outliers (6555 ms, 6679 ms) that occurred immediately after 429 retries. Including them: p95 660 ms, max 6679 ms.
- Free-tier 429s (`"The upstream provider is currently experiencing high demand"`) hit roughly 1 call in 3 at ~1 request/second. Retrying with 5–60 s backoff always succeeded.
- `usage` reports `outputTokens: 260` for a 24-option question despite the catalog's `max_tokens: 0`; `providerMetadata.gateway.cost` was `"0"` (free-tier credit) on every call. Sample in `raw_response_example.json`.

## What surprised me

1. **The model was never the bottleneck; the candidate set was.** 24 of the 25 exact-match failures are calls where the expected string was not in the candidate set at all. Restricted to the 102 calls where the expected value was reachable, accuracy was **101/102** — the single ranking error is the `list_only` gmail pick, i.e. the arm that withheld the source document.
2. **255 overlapping candidates did not confuse it.** I expected fragment n-grams (`Marcus`, `San Francisco`) to steal probability mass from the full values; they did not (top-1 0.997 mean).
3. **Confidence is trustworthy only at fine granularity.** The paragraph arm produced the most dangerous output in the whole spike: wrong-for-the-field text at confidence 1.00. A chooser threshold on top of a coarse candidate set would never fire.
4. Probability rounding to two decimals means any threshold finer than 0.01 is meaningless, and `1.00` is a saturated bucket (it only tells you "≥0.995").

## Implications for the contract decision (no decision taken)

1. **[measured] Candidate derivation sets the accuracy ceiling; it is not a tuning knob.** A strategy that cannot emit the target string scores 0 no matter how good Jev is (paragraphs 0/7; lines on labeled text 4/7). The contract needs a strategy that *includes* atomic values — line-level plus `Label: value` splitting covered 7/7 on both document shapes tested here; paragraphs alone never can.
2. **[measured] Over-generating candidates is cheap and, up to the 255 ceiling, harmless to accuracy** (7/7 at 47/95/255 candidates, +$0.00018/call, no measurable latency cost). **[inference]** That argues for offering fine and overlapping spans (line, sub-line value, sentence) rather than trying to guess one right granularity — but 255 is a hard wall that a long clipboard item will hit, so the contract still needs a rule for selecting/pruning candidates on big documents (this spike did not test documents that exceed 255 lines).
3. **[measured] The chooser/auto-insert thresholds only work at atomic granularity.** Coarse candidates yield top-1 = 1.00 on blocks containing several plausible values; atomic candidates yielded 0.69/0.31 exactly where a human would hesitate. **[inference]** Any confidence threshold in the contract should be specified together with the granularity it assumes, and calibrated against the runner-up mass (margin), not the absolute top-1, because top-1 saturates at 1.00 in the easy cases.
4. **[measured] Put the candidate text in the `criteria` and keep the source document in the `state`.** Index-only criteria cost +52% tokens for identical results; removing the document from state produced the only confident wrong answer of the run. **[inference]** The surrounding document is what disambiguates "which email is the primary one", so "send only the candidates" is not a safe token-saving shortcut.

## Limits of this spike

- One document family (a résumé, ~1 kB) and one target family (a web form with label + placeholder). Nothing here says how the strategies behave on chat logs, terminal output or prose, where "lines" and "fields" mean different things.
- The source text is a **reconstruction** of the demo PDF, not the real clipboard content: line order of right-aligned items (`2021 – Present`, `Prior experience`) and the bullet character are assumptions.
- The labeled and ambiguous variants are synthetic documents written by me to exercise strategy (c) and the ambiguity signal; the demo résumé itself has no `Label: value` lines and no duplicate values.
- Expected values are the 7 README pastes; there is no "no suitable match" option in any question, so nothing here measures rejection behaviour.
- Free-tier 429s make wall-clock latency measurements optimistic (they exclude the retry waiting time a real app would experience if it hit the same limits).
