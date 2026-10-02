# Offline analysis of the recorded Narrowing answers — four levers at $0

Brief: `docs/briefs/narrowing-offline-analysis-brief.md` (on `main`). Branch `spike/narrowing-offline` (from
`spike/narrowing` @ ba32886). Issue [#52](https://github.com/DanielMulec/jevpaste/issues/52). Research: R# = rows of
`docs/research/jev-prompting.md` (`a311fed`). **No Jev calls, no product decision.** Tags: **[measured]** = computed from
`round2/results/raw.jsonl` (design `r2b`, phases `matrix2`, `matrix2-n03fix`); **[inference]** = my reading.
Scripts (stdlib, run here, each prints its tables): `gate0.py`, `a_containment.py`, `b_gap.py`, `c_carry.py`,
`d_upstream.py`, sharing `common.py`; outputs kept as `a_out.md` … `d_out.md`.

## TL;DR
1. **Gate 0 passes** [measured]: replaying Jev's recorded choices with the recorded follow-up and speculation rule
   reproduces all 164 answered `r2b` pastes (outcome, pasted text, every step); N04 (2 pastes, HTTP 400) has no answers.
2. **A — containment mass fixes nothing and breaks hits** [measured]. No rule turns a recorded miss into a known hit.
   A1(0.5) breaks no known paste but sends 14 round-1 and 5 held-out pastes to a container whose next step was never
   asked; A1(0.6) breaks 4 known hits, A1(0.7) 9. Only C03 r0 under A1(0.5) lands on the expected paragraph (step exact,
   paste unknown); C03 r1 lands on a wrong run. R10 moves from the whole résumé to a still-too-big container (path).
3. **B — misses are low-p, but so are many hits** [measured]. Weakest step p1 < 0.40 flags 6 of the 7 misses for 9 of
   157 hits (5 round-1, 4 held-out); p1 < 0.50 flags all 7 for 27 hits. C03 hides at the last step (keep 0.69–0.70) and
   shows only at step 1 (0.38–0.39). 4 of the 7 misses are borderline cells (R10, B06).
4. **C — carry 0.01 and width 3 cost tokens they do not need** [measured]. Carry 0.05 still carries every follow-up's
   pick (43/43) with follow-ups of 5–8 options instead of median 45 (max 78); 0.1 loses 3. Width 2 saves the same 33
   calls as width 3 at median 2,589 instead of 3,911 added tokens; width 1 saves 25. Document-order ties change the
   speculated set in 3 follow-ups and no outcome or saved call.
5. **D — DigitalOcean touched 18 of 164 pastes and 1 of the 7 misses (C04 r0)** [measured], the only cell whose runs
   differ in outcome. Its runs' follow-ups were different requests (identical step-1 requests already answered
   differently on `typesafe-ai`): no clean upstream comparison. 6 of 7 misses are all-`typesafe-ai`.

## Pre-registered rules and thresholds (written before scoring)

Common
- Pastes: design `r2b`, phases `matrix2` + `matrix2-n03fix`, latest row per (cell, run), runs 0 and 1 (as `analyze_r2.py`).
  N04 (too big, no answers) is left out of A–C. Held-out = cells of `heldout.py`; round-1 = all other cells.
- Calls of a paste: the status-200 `call` rows of the same phase, cell and run logged since that key's previous paste row.
- Deciding Choice of a step: the single choice; with several choices: the follow-up, or choice `narrow_0` when all
  choices agreed (the recorded rule); a step answered ahead: its speculative question.
- Step class (as `round2/results/explore.md`): exact = the decision is the final answer (a pick or keep equal to the
  expected text or an `accept` text, keep of the whole copy compared with outer line breaks stripped; `nothing_fits`
  on a trap; `ask_user` on an ask cell); path = a picked piece that strictly contains the expected (or an accepted) text;
  miss = anything else.

A. Containment mass
- Offered pieces = the choice's option ids that map to text, except keep / `everything`, `nothing_fits`, `ask_user`.
- Q lies inside P when some occurrence of Q (UTF-8 byte offsets in the current piece, overlapping occurrences
  counted) lies within some occurrence of P. Every piece lies inside itself. Keep contains every piece.
- mass(P) = sum of p over offered pieces inside P; mass(keep) = p(keep) + sum of p over all offered pieces.
- A0 = Jev's `choice` (the recorded decision). A1(τ), τ ∈ {0.5, 0.6, 0.7}: if Jev's choice is `nothing_fits` or
  `ask_user`, unchanged; else the offered piece with mass ≥ τ that is shortest in UTF-8 bytes (ties: higher mass, then
  earlier first occurrence); if none, keep.
- A paste is replayed under the rule. A step whose new piece has no recorded answer in the same paste (step,
  follow-up or speculative) ends the replay: full outcome unknown, the deciding step is scored exact / path / miss.

B. Top-two gap
- Per deciding Choice: p1, p2 = the two largest p over all its options (keep, nothing, ask included); p1 − p2;
  p2 / p1; Jev's `confidence` for that question (answer field, else `providerMetadata.typesafe.confidence`).
- Per paste two signals: the last deciding step, and the weakest step (min p1, min gap, max p2/p1, min confidence).
- Hit / miss = the recorded policy-A paste result. Flag = signal below threshold (for p2/p1: at or above).
  Thresholds: p1 ∈ {0.3, 0.4, 0.5, 0.6, 0.7}; gap ∈ {0.05, 0.1, 0.2, 0.3, 0.4}; p2/p1 ∈ {0.33, 0.5, 0.75, 0.9};
  confidence ∈ {0.3, 0.4, 0.5, 0.6, 0.7}. Cost = hits flagged; gain = misses flagged.

C. Carry, width, ties (every recorded follow-up)
- carried(t) = pieces whose highest p over the step's choices is ≥ t; follow-up options = min(count, 252) + 3.
  (a) t ∈ {0.005, 0.01, 0.02, 0.05, 0.1}: is the follow-up's pick still carried (keep / nothing / ask: always offered).
- (b) width w ∈ {1, 2, 3, 4, 5}: candidates = the w most likely carried(0.01) pieces (ties: carry order, as recorded)
  whose next step is one non-empty choice (`r2.step_chunks`); the request form as recorded (`ids`+spec, `full`+spec,
  `ids`, `full`, first that fits by `cuts`). Saved call = the follow-up picked a speculated piece. Tokens added =
  size-model estimate with spec − without, same form. Validation: w = 3 reproduces the recorded speculated lists.
- (c) ties broken by first occurrence in the current piece instead: speculated set at w = 3 compared with the recorded
  one; outcome can change only through the 252 cut or through a pick losing / gaining its speculative answer.

D. Upstream
- Paste upstream: `typesafe-ai` when every call's `finalProvider` is `typesafe-ai`, else `any digitalocean`.
- Criteria 1–4 with the cell sets and rules of `analyze_r2.py`, per group; every miss with its upstreams; every cell
  whose run 0 and run 1 differ (outcome or pasted text), with upstreams.


## A. Containment mass (R2, R21) [measured]

| rule | group | pastes | known hit | known miss | fixed vs A0 | broken vs A0 | unknown: step exact / path / miss | unknown where A0 hit / missed |
|---|---|---|---|---|---|---|---|---|
| A0 | round-1 | 128 | 121 | 7 | 0 | 0 | 0 / 0 / 0 | 0 / 0 |
| A0 | held-out | 36 | 36 | 0 | 0 | 0 | 0 / 0 / 0 | 0 / 0 |
| A1(0.5) | round-1 | 128 | 111 | 3 | 0 | 0 | 1 / 12 / 1 | 10 / 4 |
| A1(0.5) | held-out | 36 | 31 | 0 | 0 | 0 | 0 / 2 / 3 | 5 / 0 |
| A1(0.6) | round-1 | 128 | 108 | 9 | 0 | 4 | 0 / 11 / 0 | 9 / 2 |
| A1(0.6) | held-out | 36 | 29 | 0 | 0 | 0 | 0 / 5 / 2 | 7 / 0 |
| A1(0.7) | round-1 | 128 | 102 | 15 | 0 | 8 | 0 / 11 / 0 | 11 / 0 |
| A1(0.7) | held-out | 36 | 27 | 1 | 0 | 1 | 0 / 8 / 0 | 8 / 0 |

"Unknown" = the rule's pick has no recorded next step in that paste; the deciding step is classed instead.
`=` unchanged · `hit` / `MISS` full paste known · `?exact` / `?path` / `?miss` full paste unknown, deciding step class
| cell | run | group | A0 | A1(0.5) | A1(0.6) | A1(0.7) |
|---|---|---|---|---|---|---|
| A03_strasse | 0 | round-1 | hit | ?path | ?path | ?path |
| A12_strasse_hnr | 0 | round-1 | hit | = | ?path | ?path |
| A12_strasse_hnr | 1 | round-1 | hit | = | = | ?path |
| S08_iban | 0 | round-1 | hit | = | = | ?path |
| R05_about | 0 | round-1 | hit | = | ?path | **MISS** |
| R05_about | 1 | round-1 | hit | ?path | ?path | **MISS** |
| R08_summary | 0 | round-1 | hit | ?path | **MISS** | **MISS** |
| R08_summary | 1 | round-1 | hit | = | = | ?path |
| R09_biography | 0 | round-1 | hit | ?path | **MISS** | **MISS** |
| R09_biography | 1 | round-1 | hit | ?path | **MISS** | **MISS** |
| R10_description | 0 | round-1 | **MISS** | ?path | = | = |
| R10_description | 1 | round-1 | **MISS** | ?path | = | = |
| O02_order_number | 0 | round-1 | hit | ?path | ?path | ?path |
| O02_order_number | 1 | round-1 | hit | ?path | ?path | ?path |
| O04_street | 0 | round-1 | hit | ?path | ?path | ?path |
| O04_street | 1 | round-1 | hit | = | = | ?path |
| O07_amount | 0 | round-1 | hit | = | ?path | ?path |
| B08_short_bio | 1 | round-1 | hit | ?path | = | = |
| C02_motivation | 1 | round-1 | hit | = | = | ?path |
| C03_availability | 0 | round-1 | **MISS** | ?exact | ?path | **MISS** |
| C03_availability | 1 | round-1 | **MISS** | ?miss | ?path | **MISS** |
| C04_name | 1 | round-1 | hit | ?path | ?path | **MISS** |
| N03_list_300_lines | 0 | round-1 | hit | = | = | **MISS** |
| N03_list_300_lines | 1 | round-1 | hit | = | **MISS** | **MISS** |
| H02_flat_move_in | 0 | held-out | hit | = | = | **MISS** |
| H02_flat_move_in | 1 | held-out | hit | = | = | ?path |
| H05_messages_composer | 0 | held-out | hit | ?miss | ?miss | = |
| H05_messages_composer | 1 | held-out | hit | ?miss | ?miss | = |
| H07_url_slack | 1 | held-out | hit | ?miss | = | = |
| H12_address_line_1 | 0 | held-out | hit | = | ?path | ?path |
| H12_address_line_1 | 1 | held-out | hit | = | ?path | ?path |
| H13_strasse_hausnummer | 0 | held-out | hit | = | = | ?path |
| H13_strasse_hausnummer | 1 | held-out | hit | ?path | ?path | ?path |
| H14_empfaenger | 1 | held-out | hit | ?path | ?path | ?path |
| H15_mobile | 0 | held-out | hit | = | ?path | ?path |
| H15_mobile | 1 | held-out | hit | = | = | ?path |

[inference] Mass collects in long line runs that contain many small pieces, so "smallest piece with mass ≥ τ" mostly
climbs from a correct value to a container (`4711` → `Order 4711`, `Kirchgasse 9` → name + street lines). With
overlapping runs, a run that crosses paragraph borders can hold more mass than the paragraph (C03 r1). The misses
C04 r0 (keep 0.44) and B06 (nothing fits) are untouched by construction.

## B. Top-two gap (R8) [measured]

Every miss, and every hit whose last deciding step has p1 − p2 < 0.10:

| cell | run | group | result | last p1 | p2 | p1−p2 | p2/p1 | conf | weakest p1 | weakest gap | weakest conf |
|---|---|---|---|---|---|---|---|---|---|---|---|
| R10_description | 0 | round-1 | MISS | 0.37 | 0.11 | 0.26 | 0.30 | 0.36 | 0.37 | 0.26 | 0.36 |
| R10_description | 1 | round-1 | MISS | 0.30 | 0.13 | 0.17 | 0.43 | 0.28 | 0.30 | 0.17 | 0.28 |
| B06_biography | 0 | round-1 | MISS | 0.38 | 0.30 | 0.08 | 0.79 | 0.36 | 0.38 | 0.08 | 0.36 |
| B06_biography | 1 | round-1 | MISS | 0.22 | 0.21 | 0.01 | 0.95 | 0.20 | 0.22 | 0.01 | 0.20 |
| B08_short_bio | 0 | round-1 | hit | 0.29 | 0.20 | 0.09 | 0.69 | 0.26 | 0.29 | 0.09 | 0.26 |
| B08_short_bio | 1 | round-1 | hit | 0.18 | 0.17 | 0.01 | 0.94 | 0.16 | 0.18 | 0.01 | 0.16 |
| C03_availability | 0 | round-1 | MISS | 0.70 | 0.05 | 0.65 | 0.07 | 0.69 | 0.39 | 0.24 | 0.36 |
| C03_availability | 1 | round-1 | MISS | 0.69 | 0.08 | 0.61 | 0.12 | 0.68 | 0.38 | 0.24 | 0.36 |
| C04_name | 0 | round-1 | MISS | 0.44 | 0.08 | 0.36 | 0.18 | 0.43 | 0.44 | 0.36 | 0.43 |
| H05_messages_composer | 0 | held-out | hit | 0.23 | 0.14 | 0.09 | 0.61 | 0.21 | 0.23 | 0.09 | 0.21 |
| H05_messages_composer | 1 | held-out | hit | 0.22 | 0.14 | 0.08 | 0.64 | 0.20 | 0.22 | 0.08 | 0.20 |
| H07_url_slack | 1 | held-out | hit | 0.37 | 0.33 | 0.04 | 0.89 | 0.36 | 0.37 | 0.04 | 0.36 |

Thresholds (flag = below; p2 / p1: at or above). "Last" = the deciding step that ended the paste; "weakest" = the
lowest value over the paste's deciding steps. Cost = hits flagged (a correct paste would open the chooser).

| signal | flag when | last step: hits | last: misses | weakest step: hits | weakest: misses |
|---|---|---|---|---|---|
| p1 | < 0.30 | 4 (2 / 2) | 1 B06 | 5 (3 / 2) | 1 B06 |
| p1 | < 0.40 | 5 (2 / 3) | 4 B06,R10 | 9 (5 / 4) | 6 B06,C03,R10 |
| p1 | < 0.50 | 15 (9 / 6) | 5 B06,C04,R10 | 27 (18 / 9) | 7 B06,C03,C04,R10 |
| p1 | < 0.60 | 24 (14 / 10) | 5 B06,C04,R10 | 46 (30 / 16) | 7 B06,C03,C04,R10 |
| p1 | < 0.70 | 39 (28 / 11) | 6 B06,C03,C04,R10 | 66 (45 / 21) | 7 B06,C03,C04,R10 |
| p1 − p2 | < 0.05 | 2 (1 / 1) | 1 B06 | 3 (1 / 2) | 1 B06 |
| p1 − p2 | < 0.10 | 5 (2 / 3) | 2 B06 | 7 (2 / 5) | 2 B06 |
| p1 − p2 | < 0.20 | 6 (2 / 4) | 3 B06,R10 | 14 (6 / 8) | 3 B06,R10 |
| p1 − p2 | < 0.30 | 11 (6 / 5) | 4 B06,R10 | 25 (14 / 11) | 6 B06,C03,R10 |
| p1 − p2 | < 0.40 | 18 (11 / 7) | 5 B06,C04,R10 | 39 (26 / 13) | 7 B06,C03,C04,R10 |
| p2 / p1 | ≥ 0.33 | 14 (8 / 6) | 3 B06,R10 | 34 (19 / 15) | 5 B06,C03,R10 |
| p2 / p1 | ≥ 0.50 | 6 (2 / 4) | 2 B06 | 19 (9 / 10) | 2 B06 |
| p2 / p1 | ≥ 0.75 | 2 (1 / 1) | 2 B06 | 5 (1 / 4) | 2 B06 |
| p2 / p1 | ≥ 0.90 | 1 (1 / 0) | 1 B06 | 2 (1 / 1) | 1 B06 |
| confidence | < 0.30 | 4 (2 / 2) | 2 B06,R10 | 5 (3 / 2) | 2 B06,R10 |
| confidence | < 0.40 | 5 (2 / 3) | 4 B06,R10 | 9 (5 / 4) | 6 B06,C03,R10 |
| confidence | < 0.50 | 15 (9 / 6) | 5 B06,C04,R10 | 30 (19 / 11) | 7 B06,C03,C04,R10 |
| confidence | < 0.60 | 27 (16 / 11) | 5 B06,C04,R10 | 52 (34 / 18) | 7 B06,C03,C04,R10 |
| confidence | < 0.70 | 39 (28 / 11) | 7 B06,C03,C04,R10 | 66 (45 / 21) | 7 B06,C03,C04,R10 |

[inference] The weakest step separates better than the last: a confident keep (C03 0.69, C04 r0 0.44) can follow a
weak pick. No signal is clean; held-out hits are flagged at about the same rate as round-1 hits.

## C. Carry, width, ties (R25, R27, R29) [measured]

43 recorded follow-ups (35 round-1, 8 held-out), all `ids` form; width 3 reproduces the recorded speculation 43/43.

(a) Carry threshold. Probabilities are rounded to 0.01, so 0.005 equals 0.01.

| carry ≥ | follow-ups whose pick is no longer carried | follow-up options: median / max | carried > 252 |
|---|---|---|---|
| 0.005 | 0 | 45 / 78 | 0 |
| 0.01 (now) | 0 | 45 / 78 | 0 |
| 0.02 | 0 | 13 / 30 | 0 |
| 0.05 | 0 | 5 / 8 | 0 |
| 0.1 | 3 (R08_summary r0, C02_motivation r0, C02_motivation r1) | 5 / 6 | 0 |

(b) Width (carry 0.01). Tokens added = size-model estimate with spec questions − without; 39 of 43 follow-ups picked a piece.

| width | follow-ups with spec questions | pick's next step speculated (= call saved) | follow-ups picking a piece | tokens added: median / max | sent in full-text form |
|---|---|---|---|---|---|
| 1 | 28 | 25 | 39 | 999 / 9932 | 0 |
| 2 | 38 | 33 | 39 | 2589 / 10846 | 0 |
| 3 (now) | 41 | 33 | 39 | 3911 / 16954 | 0 |
| 4 | 41 | 33 | 39 | 5552 / 16954 | 0 |
| 5 | 41 | 33 | 39 | 7376 / 22033 | 0 |

(c) Ties by document order instead of listing order (width 3): the top-3 carried order changes in 5 follow-ups, the
speculated set in 3 (B06 r0, N03 r0, N03 r1), whether the pick was speculated in none; outcomes cannot change.
No follow-up carries more than 252 pieces, so the cut never applies.

## D. Upstream (R28) [measured]

Pastes: 146 all `typesafe-ai`, 18 with a `digitalocean` call, 2 unanswered (N04). Calls: 266 / 19.

| group | upstream | 1 positives hit | 1b borderline hit | 2 traps → nothing | 3 whole / paragraph | 4 ask cells ask | 4b asks elsewhere |
|---|---|---|---|---|---|---|---|
| round-1 | typesafe-ai | 64/66 | 16/20 | 10/10 | 11/13 | 4/4 | 0 |
| round-1 | any digitalocean | 7/8 | 4/4 | 2/2 | 3/3 | 0/0 | 0 |
| held-out | typesafe-ai | 17/17 | 0/0 | 4/4 | 6/6 | 5/5 | 0 |
| held-out | any digitalocean | 1/1 | 0/0 | 0/0 | 0/0 | 1/1 | 0 |

Every miss with its upstreams:

| cell | run | group | pasted | calls: upstream per call (step / follow-up) |
|---|---|---|---|---|
| R10_description | 0 | round-1 | `Anna Reisinger⏎Born 14…` | step:typesafe-ai |
| R10_description | 1 | round-1 | `Anna Reisinger⏎Born 14…` | step:typesafe-ai |
| B06_biography | 0 | round-1 | nothing | step:typesafe-ai, follow_up:typesafe-ai |
| B06_biography | 1 | round-1 | nothing | step:typesafe-ai |
| C03_availability | 0 | round-1 | `I can start on 1 Decem…` | step:typesafe-ai, follow_up:typesafe-ai |
| C03_availability | 1 | round-1 | `I can start on 1 Decem…` | step:typesafe-ai, follow_up:typesafe-ai |
| C04_name | 0 | round-1 | `Dear Ms Hofer,⏎⏎I am w…` | step:typesafe-ai, follow_up:digitalocean |

Run 0 vs run 1, differing outcome or pasted text:

| cell | group | run 0 | upstreams r0 | run 1 | upstreams r1 |
|---|---|---|---|---|---|
| C04_name | round-1 | `Dear Ms Hofer,⏎⏎I am w…` ✗ | typesafe-ai, digitalocean | `Theo Brandner` | typesafe-ai, typesafe-ai |

Step picks also differ (same paste) in A03 (run 0 step 1 on `digitalocean`) and H14 (both `typesafe-ai`).

## Per lever: worth a live test in #52?
- **A containment mass: no.** It fixes no known miss, breaks known hits from τ 0.6, and at τ 0.5 trades exact
  step-1 picks for containers whose outcome would need more calls; the one C03 gain is matched by a C03 loss.
- **B top-two gap: no, not as a gate.** Every threshold that catches 4+ misses also opens the chooser on 5–66 correct
  pastes; keep it as a logged number (weakest-step p1) for the beta, to collect real misses.
- **C carry and width: yes, cheaply.** Carry 0.05 and width 2 (each scored alone) lose nothing on recorded data and cut follow-up size
  (45 → 5 options median) and speculative tokens (−34 %); a live check is needed only because smaller follow-ups
  change what Jev compares. Tie order: no live test; switch to document order for determinism only.
- **D upstream: yes, as a control, not a lever.** Pin `only: ["typesafe-ai"]` in the next round so that run-to-run
  differences are Jev's, not the route's; the data cannot show that the pin fixes a miss (1 of 7, n = 1).
