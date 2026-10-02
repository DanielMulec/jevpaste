recorded follow-ups: 43 (round-1 35, held-out 8)

## C(a) carry threshold
| carry ≥ | follow-ups whose pick is no longer carried | follow-up options: median / max | carried > 252 |
|---|---|---|---|
| 0.005 | 0 | 45 / 78 | 0 |
| 0.01 (now) | 0 | 45 / 78 | 0 |
| 0.02 | 0 | 13 / 30 | 0 |
| 0.05 | 0 | 5 / 8 | 0 |
| 0.1 | 3 (R08_summary r0, C02_motivation r0, C02_motivation r1) | 5 / 6 | 0 |

## C(b) speculative width (carry 0.01)
| width | follow-ups with spec questions | pick's next step speculated (= call saved) | follow-ups picking a piece | tokens added: median / max | sent in full-text form |
|---|---|---|---|---|---|
| 1 | 28 | 25 | 39 | 999 / 9932 | 0 |
| 2 | 38 | 33 | 39 | 2589 / 10846 | 0 |
| 3 (now) | 41 | 33 | 39 | 3911 / 16954 | 0 |
| 4 | 41 | 33 | 39 | 5552 / 16954 | 0 |
| 5 | 41 | 33 | 39 | 7376 / 22033 | 0 |

validation: width 3 reproduces the recorded speculated list in 43 of 43 follow-ups

## C(c) ties broken by document order (width 3)
follow-ups whose top-3 carried order changes: 5; speculated set changes: 3; pick's speculation status changes: 0
- B06_biography r0: pick keep/nothing/ask; speculated now no pick → doc order no pick
- N03_list_300_lines r0: pick `WINTER-4471-KQ`; speculated now has pick → doc order has pick
- N03_list_300_lines r1: pick `WINTER-4471-KQ`; speculated now has pick → doc order has pick
