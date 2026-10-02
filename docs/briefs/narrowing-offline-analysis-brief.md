# Brief: what the recorded Narrowing answers say about four levers, at $0

Daniel decided (2026-10-02, on [Improve Narrowing after the beta](https://github.com/DanielMulec/jevpaste/issues/52)):
before the next live Narrowing round, measure what can be measured on the calls already recorded. No Jev calls.
Data only — no product decision.

## Inputs
- The research report `docs/research/jev-prompting.md` on branch `research/jev-prompting` (`a311fed`). Register rows
  are cited as R#.
- `spike/narrowing` @ `ba32886`: `spikes/narrowing/round2/results/raw.jsonl` (every request and response verbatim),
  round 1's `spikes/narrowing/results/raw.jsonl`, the cells and expected answers (`spikes/narrowing/cells.py`,
  `round2/heldout.py`), the design and scorer (`round2/r2.py`, `round2/analyze_r2.py`), `round2/FINDINGS.md`.
- Upstream of each call: `response.providerMetadata.gateway.routing.finalProvider`.

## Where
Branch `spike/narrowing-offline` (from `spike/narrowing`), worktree `~/.pi/worktrees/jevpaste/narrowing-offline`.
Everything under `spikes/narrowing/offline/`: stdlib Python scripts and one `FINDINGS.md`. Throwaway code.

## Scope and method
- Verdict numbers come from design `r2b` pastes only (phases `matrix2` and `matrix2-n03fix`). Every result is split
  into round-1 cells (tuned on) and held-out cells. Held-out counts more, but it has no long multi-part copy going
  into a narrow field (round-2 FINDINGS), so it cannot show the part-against-whole effect.
- **Gate 0:** from the recorded answers, argmax and the recorded follow-up rule reproduce every recorded `r2b`
  outcome (pasted text, steps). Explain any mismatch before going on.
- **Write every rule and threshold into `FINDINGS.md` before scoring it, and report all of them, not the best.**
  Four known misses on 83 cells is easy to overfit.
- A rule that picks a piece whose next step was never recorded has an unknown paste outcome. Score the deciding step
  (exact / on the path = the pick contains the expected excerpt / miss, as in `round2/results/explore.md`). Score the
  full paste only where the recorded answers, speculative ones included, cover the path.

## Analyses

**A. Containment mass (R2, R21).** For every recorded deciding Choice, give each offered piece a *subtree mass*: the
sum of p over the offered pieces that lie inside it (by UTF-8 range in the current piece). `everything` / keep
contains all pieces. Rules:
- A0: argmax, the baseline.
- A1(τ), τ ∈ {0.5, 0.6, 0.7}: the smallest piece whose subtree mass is ≥ τ, else keep.

When `nothing_fits` or `ask_user` is the argmax, no rule changes the decision. Report exact / path / miss per rule,
for round-1 and held-out cells, and every cell that changes, fixed or broken: C03, C04, R10, B06, and every cell that
passes today.

**B. Top-two gap (R8).** For every deciding Choice record p1, p2, p1 − p2, p2 / p1, and Jev's `confidence` where the
response has it. Do misses separate from hits? Give a table of thresholds: correct pastes that would fall below
(the cost: the chooser on a correct paste) against misses caught. Measurement only; nothing becomes a gate.

**C. Carry threshold, speculative width, tie order (R25, R27, R29).** For every recorded follow-up:
- (a) Under carry ∈ {0.005, 0.01 (now), 0.02, 0.05, 0.1}: is the follow-up's eventual pick still carried, and how
  many options would the follow-up offer?
- (b) Under width ∈ {1, 2, 3 (now), 4, 5}: how often was the pick's next step already speculated (calls saved), and
  how many tokens are added (size model `cuts.py`)?
- (c) With ties broken by document order instead of the listing order: how many follow-ups speculate a different
  set, and does any outcome change?

**D. Upstream (R28).** Tag every paste's calls by upstream. Recompute criteria 1–4 of the `r2b` verdict for pastes
whose calls all went to `typesafe-ai` versus pastes with any `digitalocean` call. List every miss with its upstream,
and every cell whose run 0 and run 1 differ, with the upstreams.

## Deliverable
`spikes/narrowing/offline/FINDINGS.md`, at most 250 lines, tags **[measured]** and **[inference]**:
- a TL;DR;
- one section per analysis (A–D) with its tables;
- one closing line per lever: worth a live test in #52, yes or no, and why.

Name the scripts that regenerate every table.

## Rules
- No Jev calls. Do not touch `main`, jevpaste's code or the recorded `raw.jsonl` files.
- Write only under `spikes/narrowing/offline/`. Do not commit; the orchestrator commits. No subagents.
- No absolute home paths in the files.
- When done, send an intercom message to `01a0fe65-71e1-746e-a4bb-93c96000d6bf` with the path and at most 4 lines. If
  you are blocked, ask the same session.
