# Spike findings — does choice-only Narrowing pass the any-field matrix? (round 1)

Ticket: [#49](https://github.com/DanielMulec/jevpaste/issues/49). Decision it serves:
[#47 resolution](https://github.com/DanielMulec/jevpaste/issues/47#issuecomment-5845599979). Branch `spike/narrowing`
(never merged). **Data only — no product decision.** Tags: **[measured]** = in `results/raw.jsonl`;
**[inference]** = my reading of it.

**Round 1 as run, stopped by the supervisor.** Run 0 is complete (65 cells); run 1 is partial (21 cells: A01–A14,
S01–S07), stopped because run 0 had already failed criteria 1, 3, 4 and 7 and Daniel decided on a round 2 with a
changed design. No tuning was done (no cell is marked tuned).

## Verdict against the 7 fixed criteria [measured]

| # | criterion | result |
|---|---|---|
| 1 | Every positive cell hits | **FAIL** — 49/55 pastes. Misses: A12_strasse_hnr r0+r1 (`Prankergasse 77⏎Top 11`), B02_city r0 (line 1 of the bio), C02_motivation r0, C03_availability r0, C04_name r0 (all three: the whole cover letter). Borderline (not gating): 12/13, miss R06_country r0 (nothing fits). |
| 2 | Every trap cell ends in No Suitable Match | **PASS** — 8/8 trap pastes (6 trap cells in run 0; A13, A14 also in run 1) |
| 3 | Chat boxes, terminals, Notes → whole copy; About / Profile summary / Description → paragraph | **FAIL** — 6/8. W01_chrome_textarea r0 and W03_chatgpt_composer r0 pasted the paragraph. Hits: W02_terminal_prompt, W04_whatsapp_composer, C05_notes_freetext (whole copy); R05_about, R08_summary, R10_description (paragraph). |
| 4 | Chooser opens on two emails (T01) and three emails (K01), nowhere else | **FAIL** — T01 r0 opened (ask 0.25); K01 r0 did not (`marcus@anything.com` 0.79 at step 1, keep 0.81 vs ask 0.18 at step 2). No ask anywhere else, incl. S04_phone (r0, r1) and S05_mobile (r0, r1). |
| 5 | Every paste byte-exact | **PASS** — 86/86 (byte-exact check at every step; by construction) |
| 6 | Median < 2 s, nothing > 5 s | **PASS** — summed call latency per paste: median 1228 ms, p90 1986 ms, max 4006 ms (N03, 5 calls), n=85 |
| 7 | New cells | **FAIL** — N01 address line → Ort: `Graz` ✅; N02 URL → chat: **nothing fits** (0.56; whole URL 0.26) ❌; N03 300-line list: `WINTER-4471-KQ` ✅ (5 calls, 4006 ms); N04 too big: HTTP 400 `max_tokens_exceeded` ✅ (as designed: "Too long for Smart Paste") |

Latency caveats [inference]: numbers err pessimistic — `urllib` opens a new TLS connection per call, production keeps
one. 429 waits and the 0.7 s pacing are excluded from the per-paste latency and reported separately below.

## Every miss, with Jev's top options [measured]

Probabilities are Jev's for the deciding choice of each step; `keep` = the current piece unchanged.

| cell | run | step 1 top options | later steps | pasted |
|---|---|---|---|---|
| A12_strasse_hnr (Straße und Hausnummer) | 0 | `Prankergasse 77⏎Top 11` 0.84, `Prankergasse 77` 0.12, keep 0.02 | keep 0.64, `Prankergasse 77` 0.31, ask 0.02 | `Prankergasse 77⏎Top 11` |
| A12_strasse_hnr | 1 | `Prankergasse 77⏎Top 11` 0.89, `Prankergasse 77` 0.09 | keep 0.71, `Prankergasse 77` 0.26 | same |
| B02_city (City) | 0 | line 1 of the bio 0.47, nothing 0.25, keep 0.22 | keep (line 1) 0.26, `Innsbruck` 0.22, nothing 0.13, `Innsbruck.` 0.10 | the whole line |
| C02_motivation | 0 | keep (whole letter) 0.33, paragraph 2 `What draws me…` 0.32, its first line 0.12 | – | whole letter |
| C03_availability | 0 | keep 0.63, paragraph 3 0.09, its first line 0.05 | – | whole letter |
| C04_name | 0 | keep 0.67, paragraph 1 0.08, `Dear Ms Hofer,…` runs 0.07 (`Theo Brandner` not in the top 5) | – | whole letter |
| W01_chrome_textarea | 0 | paragraph 0.48, nothing 0.23, keep (whole copy) 0.18 | keep 0.91 (1374 options in 6 parallel choices + follow-up skipped: unanimous) | the paragraph |
| W03_chatgpt_composer | 0 | paragraph 0.68, keep 0.28 | keep 0.92 (1374/6) | the paragraph (smoke: 0.58 vs 0.38, same result) |
| K01_three_emails | 0 | `marcus@anything.com` 0.79, ask 0.05, nothing 0.05, the three-email run 0.05 | keep 0.81, ask 0.18 | `marcus@anything.com` |
| N02_url_chat | 0 | nothing 0.56, keep (whole URL) 0.26, `ttps://…` 0.03 | – | No Suitable Match |
| R06_country ⚠ | 0 | nothing 0.34, `Nationality: Austrian` 0.32, keep 0.06, EXPERIENCE line 0.06 | – | No Suitable Match |

Related near-misses [measured]: S04_phone picked `Phone +43 1 2345678` (0.47/0.45) over `+43 1 2345678`
(0.40/0.42) at step 1 in both runs and reached the value one step later (3 calls). O07_amount: `Total EUR 129,90`
0.63 → `129,90` 0.68 → keep. B08_short_bio: ask 0.16 at step 1 (paragraph 1 won at 0.28). T01 run 0: ask 0.25,
`wren.castellan@example.net` 0.23, keep 0.18 — the smoke run of the same request gave keep 0.28 > ask 0.23, so
T01 flips between runs.

## What round 2 should know [inference unless tagged]

Failure classes, from the table above:
1. **Containment when the exact piece is on offer next to a bigger one.** "If no option is exactly that, choose the
   smallest option that contains all of it" was read as licence to pick a containing piece even when the exact
   piece was offered: A12 took `Prankergasse 77⏎Top 11` (0.84–0.89) over `Prankergasse 77`, then **kept** it
   (0.64/0.71); B02 kept the whole line over `Innsbruck` (0.26 vs 0.22); S04/O07 took the labelled line first. The
   "unchanged" option at later steps is sticky: once Jev lands on a too-big piece it tends to keep it. When the
   exact piece wins at step 1 (most address/signature/order cells) the confirm step is ~1.00 [measured].
2. **Whole copy vs a part.** Both directions fail. Chat-like places (W01 Chrome textarea, W03 ChatGPT) prefer the
   prose paragraph over "everything that was copied" (0.48–0.68 vs 0.18–0.38); the cover-letter fields C02–C04
   prefer the whole letter over their own paragraph/name (keep 0.33–0.67). The whole-copy description carries no
   text (it points at `source_document`) while every other option carries its full text — possibly a factor.
   W02 terminal (0.51) and W04 WhatsApp (0.68) and C05 Notes (0.55) did keep the whole copy.
3. **URL → nothing fits.** A single-line URL into ChatGPT: nothing fits 0.56 > whole URL 0.26. The "nothing fits"
   wording ("no part of `source_document` is what the user means to paste there") competes with "everything that
   was copied" in free places; no other place-neutral cue tells Jev that a chat box takes anything.
4. **Three emails → no ask.** Consistent with the contract spike (3 equal emails → 0.91–0.95 on one): Jev commits
   to the first email (0.79) and gives ask only 0.05 at step 1 and 0.18 at the confirm step. Two emails in T01
   hovered at ask 0.23–0.25 vs keep 0.18–0.28, i.e. a coin flip. The supervisor's question — does "all of it" pull
   toward the whole copy when two values compete? — T01: keep (the whole two-line copy, which contains both
   emails) got 0.18–0.28 and the two-line run from `4711` 0.17–0.19 [measured]; so roughly 0.4 of the mass went to
   pieces containing **both** emails, which fits that reading.
5. **Straße + next line.** `Prankergasse 77⏎Top 11` (street line + the Adresszusatz line) beat the exact street line:
   Jev reads "Straße und Hausnummer" as possibly including the door/stair addition, and the containment clause
   then allows the bigger piece.

Design facts that held [measured]:
- Flattening (line runs + token runs in one choice when ≤ 252 pieces) reached values in 2 calls on the address,
  signature, order, tickets and N01; the confirm step then keeps the value at 0.97–1.00.
- Parallel choices + follow-up worked (N03: 2 choices at steps 1 and 2; W01/W03: 6 choices, unanimous → follow-up
  skipped). The follow-up carry list (every piece with p ≥ 0.01) was never cut.
- Traps: nothing fits won all 8 trap pastes (0.50–0.88).
- Edge cuts (near-duplicates such as `ttps://…`, `43 1 2345678`) drew at most 0.03–0.09.

Plumbing a successor needs:
- `run.py`: `reach` (offline paths and call counts), `smoke CELL…`, `matrix RUN [CELL|GROUP…]` (resumes: skips every
  (cell, run) already logged as a `paste` row), `probe` / `probe_total` (size limits). Every call is a `call` row
  with request + response verbatim, `waits` (429/503 retries), `latency_ms` (successful attempt only),
  `request_bytes`; every paste is a `paste` row with all steps. `analyze.py` → `results/report.md`.
- Free tier: 103 retry waits, 2,581 s in total during the matrix; `retry-after` up to 60 s; pacing 0.7 s. About
  ~40 pastes per 25 min. Kill with `pkill -9 -f run.py`.
- **Size model** (`cuts.py`): Jev's tokens are not public; `usage.inputTokens` fits 0.25/letter, 1.0/digit,
  1.0/other non-space char, 12/option, 250/question (prose over-estimated by 10–35 %, digit-heavy logs
  under-estimated by ≤ 3 %); budgets 92 % of 32k (state + one question) and 64k (state + all questions). A chars/token
  model (2.2) under-counted digit-heavy text and got a `max_tokens_exceeded` in the first N03 smoke.

## The too-big facts [measured]

- Probe (`run.py probe`): prefixes of the 3000-line log with a minimal step-1 question (unchanged, nothing fits,
  ask). **Accepted up to 800 lines = 57,507 chars = 32,869 input tokens; refused from 806 lines** (60,378 request
  bytes). Accepted points: 637 lines → 26,311 tokens, 721 → 29,690, 763 → 31,379, 784 → 32,225, 795 → 32,668,
  800 → 32,869. Refused: 806, 975, 1650, 3000 lines.
- Status is **HTTP 400** every time. The body alternates between two forms, depending on which provider the
  Gateway tried last (it retries TypeSafe via DigitalOcean and back):
  - `{"error": {"message": "{\"error_type\":\"max_tokens_exceeded\"}", "type": "AI_APICallError", "param": {"error": "{\"error_type\":\"max_tokens_exceeded\"}", "statusCode": 400, "name": "AI_APICallError", "message": "{\"error_type\":\"max_tokens_exceeded\"}", "isRetryable": false, "type": "AI_APICallError"}}, "providerMetadata": {"gateway": {"routing": {…}}}}`
  - `{"error": {"message": "typesafe returned status 400", "type": "AI_APICallError", "param": {"error": "typesafe returned status 400", "statusCode": 400, "name": "AI_APICallError", "message": "typesafe returned status 400", "isRetryable": false, "type": "AI_APICallError"}}, "providerMetadata": {"gateway": {"routing": {…}}}}` — here the per-attempt `providerAttempts[].error` still holds `{"error_type":"max_tokens_exceeded"}` for the TypeSafe attempt (the other attempt: `Service temporarily unavailable`, 503).
  Full bodies are in `results/raw.jsonl` (`cell: "N04_probe"`, `status: 400`).
- **The state counts once across parallel questions** (`run.py probe_total`): state = the 300-line log, 3 questions
  of ~15k tokens each → **accepted at 56,901 input tokens** (per-question counting would be ~83k); 4 questions
  (~71k) → refused, 400 `max_tokens_exceeded`.
- N04 in the matrix (3000 lines, 216k chars, 479,212 request bytes) → 400 `max_tokens_exceeded` in 1,853 ms, not
  billed.
- The first N03 smoke (state + one question estimated too small) → 400 `max_tokens_exceeded`: the per-question
  limit (state + longest question ≈ 32.8k tokens) binds, not only the state.

## Design (as run)

**Cutting** (`cuts.py`; character classes only, no meaning rules):
- Line breaks → lines. A line piece = run of consecutive non-blank lines (inner blank lines kept; starts and ends on a
  non-blank line; outer spaces trimmed).
- Tokens = maximal run of letters/digits (`str.isalnum`), or any single other non-space character. Token piece = run
  of consecutive tokens within one line (exact slice).
- Characters: every substring of a single token.
- Edge cuts: one-line piece → every cut at a character inside its first/last token; multi-line piece → four unit
  cuts (without its first token / first character / last token / last character). With these, every substring that
  starts and ends on a non-space character is reachable (exhaustive check on sample texts, `python3 cuts.py`).

**Children of piece P** (offered next to "P unchanged", deduplicated by text, P excluded):
- ≥ 2 lines: every line run + edge cuts; **flattened** with every token run of every single line when that is ≤ 252
  pieces and fits the size budget.
- one line of ≥ 2 tokens: every token run + edge cuts. One token: every character substring. One character: final,
  no call.
- Too big for one request: units grouped into blocks of b (smallest b that fits): every run of blocks + every single
  unit (+ edge cuts if they still fit).
- > 252 pieces or over one question's size: several choice questions in **one** request (document order,
  "unchanged" in each), then a follow-up choice over unchanged + every piece with p ≥ 0.01 in any of them + nothing
  fits + ask. If all parallel choices pick the same non-piece option, no follow-up (Jev's own answer).
- Outcome = argmax of the deciding choice. Byte-exact check of every pick. Chooser list = every option with p > 0 in
  the deciding choice (without nothing/ask), most likely first. Whole-copy pastes: outer line breaks stripped.

**Request**: `state = {source_document, target_context}` (production shape) at every step; options `keep`,
`e000…`, `nothing_fits`, `ask_user`; piece descriptions = the full excerpt text, verbatim (real line breaks, no
cut). Step 1: `instructions` = string; later steps: `instructions = {"current_piece": P, "question": …}`.

Offline expectation (`run.py reach`) [measured]: every expected excerpt reachable; ideal calls per paste 1 ×14,
2 ×43, 3 ×7, 5 ×1 (N03). Observed: mean 1.90 calls (1×22, 2×53, 3×10, 5×1).

## Wordings (verbatim)

`INSTRUCTIONS_FIRST` (step 1, string):
> The user copied `source_document` and is pasting into the place described by `target_context`. One option is everything that was copied, as it is. Every other excerpt option is an exact excerpt cut from `source_document`; its description is that excerpt, character for character. Choose the option that is exactly what the user means to paste into `target_context`. If no option is exactly that, choose the smallest option that contains all of it.

`INSTRUCTIONS_LATER` (the `question` field; `current_piece` beside it):
> The user copied `source_document` and is pasting into the place described by `target_context`. `current_piece` is an exact excerpt of `source_document`. One option is `current_piece` kept as it is. Every other excerpt option is a smaller exact excerpt cut from `current_piece`; its description is that excerpt, character for character. Choose the option that is exactly what the user means to paste into `target_context`. If no option is exactly that, choose the smallest option that contains all of it.

`keep` at step 1:
> Everything that was copied, as it is: all of `source_document`, nothing cut away.

`keep` at later steps:
> `current_piece` as it is, nothing cut away.

`nothing_fits`:
> Nothing that was copied belongs in `target_context`: no part of `source_document` is what the user means to paste there.

`ask_user`:
> Two or more different excerpts could each be what the user means to paste into `target_context`, and nothing in `target_context` says which one; the user has to pick.

Parallel choices and the follow-up use the same wording. The supervisor checked all six at GATE A.

## Cells

- 56 cells of `spikes/any-field/fixtures.py` (6 trap cells; T01 now expects "ask").
- Whole-copy places (`spikes/free-text/situations.py` targets, its 6-line item): W01 Chrome comment textarea (S07),
  W02 terminal prompt (S02; `app_name` Ghostty — Herdr runs inside it), W03 ChatGPT composer (S01a), W04 WhatsApp
  (S04). C05 Notes is the cover-letter item's cell (the résumé has none).
- K01: `spikes/abstention` RESUME_THREE_EMAILS into "Email address" with a production-shaped context written for
  this spike (`cells.py`).
- N01 `Mira Holzner, Prankergasse 77, 8020 Graz` → Ort; N02
  `https://www.miraholzner.example/portfolio/kiln-series-2026?view=grid` → ChatGPT composer; N03 300-line log,
  `WINTER-4471-KQ` on line 238, into a checkout "Gift card or discount code" field; N04 the same log at 3000 lines.

## Files

`cuts.py` (cutting, size model, reachability), `cells.py` (all cells), `run.py` (Narrowing, runner, probes),
`analyze.py` → `results/report.md`, `results/raw.jsonl` (every request and response verbatim),
`results/matrix.log` (runner output).

## Generated report (analyze.py, round 1 as run)

### Verdict against the 7 fixed criteria (both runs of every cell)

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | **FAIL**: 49/55 pastes hit; misses: A12_strasse_hnr r0 → `Prankergasse 77⏎Top 11`, A12_strasse_hnr r1 → `Prankergasse 77⏎Top 11`, B02_city r0 → `Hi, I'm Lena Vogt, a ceramicist wo…`, C02_motivation r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`, C03_availability r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`, C04_name r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`. Borderline: 12/13 hit |
| 2 | every trap cell ends in No Suitable Match | PASS: 8/8 trap pastes (A13_passwort_NEG, A14_fax_NEG, S09_fax_NEG, R07_linkedin_NEG, O09_coupon_NEG, B05_phone_NEG) |
| 3 | whole copy in W01_chrome_textarea, W02_terminal_prompt, W03_chatgpt_composer, W04_whatsapp_composer, C05_notes_freetext; paragraph in R05_about, R08_summary, R10_description | **FAIL**: 6/8; misses: W01_chrome_textarea r0 → `Product designer with nine years o…`, W03_chatgpt_composer r0 → `Product designer with nine years o…` |
| 4 | chooser opens on two and three emails (T01_email_two_lines, K01_three_emails), nowhere else (incl. S04_phone, S05_mobile) | **FAIL**: opened 1/2; asks elsewhere: none; not opened: K01_three_emails r0 → `marcus@anything.com` |
| 5 | every paste byte-exact | PASS: 86/86 |
| 6 | median < 2 s, nothing > 5 s (summed call latency per paste) | PASS: median 1228 ms, p90 1986 ms, max 4006 ms (n=85) |
| 7 | new cells | N01_address_line_ort 1/1 (`Graz`); N02_url_chat 0/1 (nothing); N03_list_300_lines 1/1 (`WINTER-4471-KQ`); N04_too_big 1/1 (error 400) |

### Per-cell table

Steps: `pick (options[/choices], p)`, `keep` = the current piece unchanged. ⚠ = borderline (not gating), ✎ = tuned.

| cell | expected | run | outcome | hit | calls | ms | steps | p(ask) max | p(nothing) max |
|---|---|---|---|---|---|---|---|---|---|
| A01_vorname | `Mira` | 0 | `Mira` | ✅ | 2 | 1297 | `Mira` (113, 0.85) › keep (10, 0.99) | 0.00 | 0.01 |
| A01_vorname | `Mira` | 1 | `Mira` | ✅ | 2 | 1086 | `Mira` (113, 0.88) › keep (10, 1.00) | 0.00 | 0.00 |
| A02_nachname | `Holzner` | 0 | `Holzner` | ✅ | 2 | 1826 | `Holzner` (113, 0.90) › keep (28, 1.00) | 0.00 | 0.00 |
| A02_nachname | `Holzner` | 1 | `Holzner` | ✅ | 2 | 961 | `Holzner` (113, 0.90) › keep (28, 0.99) | 0.00 | 0.00 |
| A03_strasse ⚠ | `Prankergasse` | 0 | `Prankergasse` | ✅ | 3 | 1629 | `Prankergasse 77` (113, 0.65) › `Prankergasse` (15, 0.56) › keep (74, 0.98) | 0.02 | 0.01 |
| A03_strasse ⚠ | `Prankergasse` | 1 | `Prankergasse` | ✅ | 3 | 1587 | `Prankergasse 77` (113, 0.70) › `Prankergasse` (15, 0.56) › keep (74, 0.97) | 0.02 | 0.01 |
| A04_hausnummer | `77` | 0 | `77` | ✅ | 2 | 1138 | `77` (113, 0.86) › keep (2, 1.00) | 0.00 | 0.02 |
| A04_hausnummer | `77` | 1 | `77` | ✅ | 2 | 1010 | `77` (113, 0.84) › keep (2, 1.00) | 0.00 | 0.03 |
| A05_adresszusatz | `Top 11` | 0 | `Top 11` | ✅ | 2 | 2198 | `Top 11` (113, 0.84) › keep (6, 0.92) | 0.01 | 0.04 |
| A05_adresszusatz | `Top 11` | 1 | `Top 11` | ✅ | 2 | 1410 | `Top 11` (113, 0.83) › keep (6, 0.93) | 0.01 | 0.01 |
| A06_plz | `8020` | 0 | `8020` | ✅ | 2 | 1223 | `8020` (113, 0.91) › keep (9, 1.00) | 0.00 | 0.03 |
| A06_plz | `8020` | 1 | `8020` | ✅ | 2 | 1253 | `8020` (113, 0.84) › keep (9, 1.00) | 0.00 | 0.00 |
| A07_ort | `Graz` | 0 | `Graz` | ✅ | 2 | 1298 | `Graz` (113, 0.95) › keep (10, 1.00) | 0.00 | 0.02 |
| A07_ort | `Graz` | 1 | `Graz` | ✅ | 2 | 1063 | `Graz` (113, 0.95) › keep (10, 1.00) | 0.00 | 0.01 |
| A08_land | `Österreich` | 0 | `Österreich` | ✅ | 2 | 1134 | `Österreich` (113, 0.92) › keep (53, 0.98) | 0.00 | 0.01 |
| A08_land | `Österreich` | 1 | `Österreich` | ✅ | 2 | 1186 | `Österreich` (113, 0.88) › keep (53, 0.98) | 0.00 | 0.01 |
| A09_email | `mira.holzner@example.org` | 0 | `mira.holzner@example.org` | ✅ | 2 | 1295 | `mira.holzner@example.o…` (113, 0.93) › keep (32, 1.00) | 0.00 | 0.00 |
| A09_email | `mira.holzner@example.org` | 1 | `mira.holzner@example.org` | ✅ | 2 | 931 | `mira.holzner@example.o…` (113, 0.98) › keep (32, 1.00) | 0.00 | 0.00 |
| A10_website | `https://www.miraholzner.ex…` | 0 | `https://www.miraholzner.example` | ✅ | 2 | 1082 | `https://www.miraholzne…` (113, 0.92) › keep (53, 0.98) | 0.00 | 0.00 |
| A10_website | `https://www.miraholzner.ex…` | 1 | `https://www.miraholzner.example` | ✅ | 2 | 1356 | `https://www.miraholzne…` (113, 0.91) › keep (53, 0.96) | 0.00 | 0.02 |
| A11_telefon | `06608405534` | 0 | `06608405534` | ✅ | 2 | 1626 | `06608405534` (113, 0.97) › keep (61, 0.99) | 0.00 | 0.01 |
| A11_telefon | `06608405534` | 1 | `06608405534` | ✅ | 2 | 1496 | `06608405534` (113, 0.97) › keep (61, 0.99) | 0.00 | 0.01 |
| A12_strasse_hnr | `Prankergasse 77` | 0 | `Prankergasse 77⏎Top 11` | ❌ | 2 | 1493 | `Prankergasse 77⏎Top 11` (113, 0.84) › keep (11, 0.64) | 0.02 | 0.00 |
| A12_strasse_hnr | `Prankergasse 77` | 1 | `Prankergasse 77⏎Top 11` | ❌ | 2 | 1588 | `Prankergasse 77⏎Top 11` (113, 0.89) › keep (11, 0.71) | 0.02 | 0.00 |
| A13_passwort_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 578 | nothing_fits (113, 0.84) | 0.06 | 0.84 |
| A13_passwort_NEG | ∅ (nothing) | 1 | nothing | ✅ | 1 | 752 | nothing_fits (113, 0.88) | 0.05 | 0.88 |
| A14_fax_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 652 | nothing_fits (113, 0.61) | 0.02 | 0.61 |
| A14_fax_NEG | ∅ (nothing) | 1 | nothing | ✅ | 1 | 754 | nothing_fits (113, 0.62) | 0.02 | 0.62 |
| S01_first_name | `Jonas` | 0 | `Jonas` | ✅ | 2 | 1191 | `Jonas` (203, 0.54) › keep (15, 0.99) | 0.02 | 0.02 |
| S01_first_name | `Jonas` | 1 | `Jonas` | ✅ | 2 | 1209 | `Jonas` (203, 0.51) › keep (15, 1.00) | 0.02 | 0.02 |
| S02_last_name | `Prell` | 0 | `Prell` | ✅ | 2 | 1447 | `Prell` (203, 0.86) › keep (14, 0.99) | 0.00 | 0.01 |
| S02_last_name | `Prell` | 1 | `Prell` | ✅ | 2 | 1353 | `Prell` (203, 0.62) › keep (14, 0.99) | 0.00 | 0.01 |
| S03_job_title | `Product Lead` | 0 | `Product Lead` | ✅ | 2 | 1779 | `Product Lead` (203, 0.77) › keep (12, 1.00) | 0.00 | 0.04 |
| S03_job_title | `Product Lead` | 1 | `Product Lead` | ✅ | 2 | 1067 | `Product Lead` (203, 0.80) › keep (12, 1.00) | 0.00 | 0.04 |
| S04_phone | `+43 1 2345678` | 0 | `+43 1 2345678` | ✅ | 3 | 1915 | `Phone +43 1 2345678` (203, 0.47) › `+43 1 2345678` (25, 0.85) › keep (16, 1.00) | 0.00 | 0.02 |
| S04_phone | `+43 1 2345678` | 1 | `+43 1 2345678` | ✅ | 3 | 2237 | `Phone +43 1 2345678` (203, 0.45) › `+43 1 2345678` (25, 0.83) › keep (16, 1.00) | 0.01 | 0.02 |
| S05_mobile | `+43 660 1112233` | 0 | `+43 660 1112233` | ✅ | 2 | 1369 | `+43 660 1112233` (203, 0.70) › keep (16, 1.00) | 0.00 | 0.00 |
| S05_mobile | `+43 660 1112233` | 1 | `+43 660 1112233` | ✅ | 2 | 2192 | `+43 660 1112233` (203, 0.80) › keep (16, 1.00) | 0.00 | 0.00 |
| S06_email | `jonas.prell@example.com` | 0 | `jonas.prell@example.com` | ✅ | 2 | 1388 | `jonas.prell@example.co…` (203, 0.95) › keep (33, 1.00) | 0.00 | 0.00 |
| S06_email | `jonas.prell@example.com` | 1 | `jonas.prell@example.com` | ✅ | 2 | 931 | `jonas.prell@example.co…` (203, 0.94) › keep (33, 1.00) | 0.00 | 0.00 |
| S07_website | `www.prell.example` | 0 | `www.prell.example` | ✅ | 2 | 1250 | `www.prell.example` (203, 0.81) › keep (22, 1.00) | 0.00 | 0.04 |
| S07_website | `www.prell.example` | 1 | `www.prell.example` | ✅ | 2 | 1487 | `www.prell.example` (203, 0.83) › keep (22, 1.00) | 0.00 | 0.04 |
| S08_iban ⚠ | `AT61 1904 3002 3457 3201` | 0 | `AT61 1904 3002 3457 3201` | ✅ | 2 | 1087 | `AT61 1904 3002 3457 32…` (203, 0.68) › keep (21, 1.00) | 0.00 | 0.00 |
| S09_fax_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 440 | nothing_fits (203, 0.81) | 0.00 | 0.81 |
| R01_full_name | `Anna Reisinger` | 0 | `Anna Reisinger` | ✅ | 2 | 1179 | `Anna Reisinger` (48, 0.96) › keep (14, 1.00) | 0.00 | 0.00 |
| R02_birthdate | `14 March 1991` | 0 | `14 March 1991` | ✅ | 3 | 2299 | `Born 14 March 1991 in …` (48, 0.58) › `14 March 1991` (27, 0.94) › keep (10, 1.00) | 0.03 | 0.15 |
| R03_birthplace | `Linz` | 0 | `Linz` | ✅ | 3 | 2508 | `Born 14 March 1991 in …` (48, 0.62) › `Linz` (27, 0.77) › keep (10, 1.00) | 0.03 | 0.10 |
| R04_nationality | `Austrian` | 0 | `Austrian` | ✅ | 3 | 2245 | `Nationality: Austrian` (48, 0.92) › `Austrian` (23, 0.90) › keep (36, 0.97) | 0.01 | 0.03 |
| R05_about | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 1578 | `Data engineer with eig…` (48, 0.70) › keep (9, 0.94) | 0.03 | 0.01 |
| R06_country ⚠ | `Austria` | 0 | nothing | ❌ | 1 | 758 | nothing_fits (48, 0.34) | 0.04 | 0.34 |
| R07_linkedin_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 435 | nothing_fits (48, 0.57) | 0.04 | 0.57 |
| R08_summary | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 1455 | `Data engineer with eig…` (48, 0.71) › keep (9, 0.97) | 0.03 | 0.00 |
| R09_biography ⚠ | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 1493 | `Data engineer with eig…` (48, 0.49) › keep (9, 0.77) | 0.05 | 0.03 |
| R10_description ⚠ | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 2340 | `Data engineer with eig…` (48, 0.48) › keep (9, 0.98) | 0.02 | 0.00 |
| O01_email | `wren.castellan@example.net` | 0 | `wren.castellan@example.net` | ✅ | 2 | 989 | `wren.castellan@example…` (160, 0.97) › keep (32, 1.00) | 0.00 | 0.00 |
| O02_order_number | `4711` | 0 | `4711` | ✅ | 2 | 1969 | `4711` (160, 0.80) › keep (9, 1.00) | 0.03 | 0.00 |
| O03_recipient | `Lise Adler` | 0 | `Lise Adler` | ✅ | 2 | 1306 | `Lise Adler` (160, 0.91) › keep (10, 0.99) | 0.00 | 0.00 |
| O04_street | `Hauptstr. 5` | 0 | `Hauptstr. 5` | ✅ | 2 | 1167 | `Hauptstr. 5` (160, 0.69) › keep (13, 1.00) | 0.03 | 0.02 |
| O05_postal_code | `4020` | 0 | `4020` | ✅ | 2 | 1809 | `4020` (160, 0.78) › keep (9, 1.00) | 0.05 | 0.02 |
| O06_city | `Linz` | 0 | `Linz` | ✅ | 2 | 1314 | `Linz` (160, 0.91) › keep (10, 1.00) | 0.02 | 0.02 |
| O07_amount ⚠ | `129,90` | 0 | `129,90` | ✅ | 3 | 1725 | `Total EUR 129,90` (160, 0.63) › `129,90` (20, 0.68) › keep (9, 0.98) | 0.03 | 0.02 |
| O08_tracking | `00340434161234567890` | 0 | `00340434161234567890` | ✅ | 2 | 1181 | `00340434161234567890` (160, 0.67) › keep (198, 0.99) | 0.00 | 0.01 |
| O09_coupon_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 597 | nothing_fits (160, 0.74) | 0.04 | 0.74 |
| B01_handle | `@mira_h` | 0 | `@mira_h` | ✅ | 3 | 1998 | `I post new glazes and …` (13, 0.34) › `@mira_h` (170, 0.40) › keep (10, 0.96) | 0.03 | 0.28 |
| B02_city | `Innsbruck` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ❌ | 2 | 1184 | `Hi, I'm Lena Vogt, a c…` (13, 0.47) › keep (189, 0.26) | 0.02 | 0.25 |
| B03_bio ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 1 | 541 | keep (13, 0.78) | 0.03 | 0.00 |
| B04_birth_year | `1994` | 0 | `1994` | ✅ | 3 | 1801 | `Born in 1994 and raise…` (13, 0.54) › `1994` (212, 0.35) › keep (9, 1.00) | 0.02 | 0.21 |
| B05_phone_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 778 | nothing_fits (13, 0.50) | 0.02 | 0.50 |
| B06_biography ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 1 | 798 | keep (13, 0.46) | 0.07 | 0.13 |
| B07_about_me ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 1 | 517 | keep (13, 0.73) | 0.05 | 0.00 |
| B08_short_bio ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 2 | 1047 | `Hi, I'm Lena Vogt, a c…` (13, 0.28) › keep (6, 0.73) | 0.16 | 0.01 |
| T01_email_two_lines | ask | 0 | ask → [`wren.castellan@example.n…`, `Ticket 4711 wren.castell…`, `4711 wren.castellan@exam…`, `lise.adler@example.net`] | ✅ | 1 | 446 | ask_user (82, 0.25) | 0.25 | 0.03 |
| C01_cover_letter ⚠ | `I am writing to apply for …` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ✅ | 1 | 832 | keep (49, 0.82) | 0.01 | 0.00 |
| C02_motivation | `What draws me to Grünraum …` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ❌ | 1 | 1228 | keep (49, 0.33) | 0.01 | 0.00 |
| C03_availability | `I can start on 1 December …` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ❌ | 1 | 678 | keep (49, 0.63) | 0.02 | 0.00 |
| C04_name | `Theo Brandner` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ❌ | 1 | 510 | keep (49, 0.67) | 0.04 | 0.00 |
| C05_notes_freetext ⚠ | `Dear Ms Hofer,⏎⏎I am writi…` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ✅ | 1 | 806 | keep (49, 0.55) | 0.07 | 0.06 |
| W01_chrome_textarea | `Marlene Oberholzer⏎marlene…` | 0 | `Product designer with nine years o…` | ❌ | 2 | 1755 | `Product designer with …` (24, 0.48) › keep (1374/6, 0.91) | 0.03 | 0.23 |
| W02_terminal_prompt | `Marlene Oberholzer⏎marlene…` | 0 | `Marlene Oberholzer⏎marlene.oberhol…` | ✅ | 1 | 421 | keep (24, 0.51) | 0.09 | 0.21 |
| W03_chatgpt_composer | `Marlene Oberholzer⏎marlene…` | 0 | `Product designer with nine years o…` | ❌ | 2 | 1774 | `Product designer with …` (24, 0.68) › keep (1374/6, 0.92) | 0.00 | 0.01 |
| W04_whatsapp_composer | `Marlene Oberholzer⏎marlene…` | 0 | `Marlene Oberholzer⏎marlene.oberhol…` | ✅ | 1 | 667 | keep (24, 0.68) | 0.02 | 0.00 |
| K01_three_emails | ask | 0 | `marcus@anything.com` | ❌ | 2 | 1545 | `marcus@anything.com` (234, 0.79) › keep (22, 0.81) | 0.18 | 0.05 |
| N01_address_line_ort | `Graz` | 0 | `Graz` | ✅ | 2 | 1112 | `Graz` (41, 0.86) › keep (10, 0.98) | 0.01 | 0.01 |
| N02_url_chat | `https://www.miraholzner.ex…` | 0 | nothing | ❌ | 1 | 574 | nothing_fits (233, 0.56) | 0.02 | 0.56 |
| N03_list_300_lines | `WINTER-4471-KQ` | 0 | `WINTER-4471-KQ` | ✅ | 5 | 4006 | `2026-09-12 12:41:02 IN…` (303/2, 0.77) › `WINTER-4471-KQ` (322/2, 0.54) › keep (20, 0.85) | 0.00 | 0.37 |
| N04_too_big | too long | 0 | error 400 | ✅ | 1 | 1853 | None (3001/12, –) | 0.00 | 0.00 |

### Latency, calls, cost

- Per paste (summed call latency, 429 waits excluded): n=85, median 1228 ms, p90 1986 ms, max 4006 ms.
  - 1 call(s): n=21, median 652 ms, p90 806 ms, max 1228 ms
  - 2 call(s): n=53, median 1298 ms, p90 1803 ms, max 2340 ms
  - 3 call(s): n=10, median 1956 ms, p90 2320 ms, max 2508 ms
  - 5 call(s): n=1, median 4006 ms, p90 4006 ms, max 4006 ms
- Per call: warm n=160 median 633 ms, p90 1006 ms; cold (first call of a process) n=2 median 698 ms.
- Calls per paste (matrix, both runs): mean 1.90; distribution 1×22, 2×53, 3×10, 5×1.
- Retry waits (429/503, pacing excluded) during the matrix: 103 waits, 2581 s in total.
- Billed Jev calls for the whole spike: 184 (budget 900); input tokens 1087430; Gateway cost $0.0457.
- Follow-up carry list cut: never.

