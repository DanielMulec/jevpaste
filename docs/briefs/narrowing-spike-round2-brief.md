# Worker brief — Narrowing spike, round 2 (issue #49)

Ticket: [Spike: does choice-only Narrowing pass the any-field matrix?](https://github.com/DanielMulec/jevpaste/issues/49)
(AFK task; the ticket body holds the **7 fixed pass criteria**, which still apply unchanged).
You are a fresh `anthropic/claude-opus-5-5:high` worker. The supervisor's intercom id is in your launch prompt;
use exactly that id. Protocol: `intercom send <id> "[narrowing-r2] step N done — <fact>"` after each numbered step,
`intercom ask` at **GATE A** and whenever something blocks you. Never sign up for anything, never print
`~/.config/jevpaste/env`, no LLM calls, synthetic data only. Daniel (owner) speaks only through the supervisor.

## Why there is a round 2
Round 1 (choice-only Narrowing, as designed) **failed criteria 1, 3, 4 and 7** in its first run: 55 of 65 cells
hit, all 6 traps passed, median ≈ 1.2 s. Its report is the round-1 comment on #49, and the full data is
`spikes/narrowing/FINDINGS.md` + `spikes/narrowing/results/raw.jsonl` on your branch. The failure classes the
supervisor sees (verify them against the data; don't take them on trust):
1. **Containment judgment.** When the exact value isn't among a step's options, Jev must pick "the smallest option
   that contains all of it" and often keeps the big piece instead. Examples: the cover letter into "Name",
   "Motivation", "Availability" (keeps the whole letter, 0.67 / 0.33 / …); a city inside the bio paragraph
   (paragraph kept, 0.26 vs `Innsbruck` 0.22).
2. **Everything vs a part.** In chat boxes (Chrome comment textarea, ChatGPT composer) Jev picks the bio paragraph
   over the whole copy (0.48 vs 0.18). The terminal and WhatsApp got the whole copy.
3. **A lone URL into a chat composer → "nothing fits"** (0.56 vs the URL as-is 0.26).
4. **Three emails of one person → no ask:** the first email at 0.79, "ask the user" 0.05, then kept at 0.81 (ask
   0.18). (Two emails did ask, 0.25.)
5. **Straße with a separate house-number field** got the street plus the next line (`Prankergasse 77\nTop 11`).

## Daniel's decisions for round 2 (2026-09-26)
- **Yes to a round 2 with a changed design**, still Python and still no Swift, with every cell re-run twice.
- **Measure a place choice (D4 below)** in the same request. It stays measurement only: whether it ships is his
  decision once the data is in.
- **Three emails: "ask the user" stays the goal.** If it still fails after round 2, it goes back to him.

## What stays fixed (the contract — read the #47 resolution comment again)
`gh api repos/DanielMulec/jevpaste/issues/comments/5845599979 -q .body`, plus `CONTEXT.md` on `main`
(`/Users/danielmulec/Projekte/experiments/jevpaste/CONTEXT.md`): **Narrowing**, Candidate, Candidate Chooser, No
Suitable Match, Direct Paste.
- Every decision is a Jev **choice**. There are **no yes/no questions** (no `noul`, no boolean gate). TypeSafe's own
  "check whether an answer exists" recipe uses a yes/no, so don't copy it.
- **No local rule decides meaning:** no heading or `Label:` rules, no email/phone/URL patterns, no field or place
  vocabulary in any wording, instruction, criterion or example. Cutting uses character classes only.
- **No piece is ever dropped.** Every contiguous substring that starts and ends on a non-space character stays
  reachable (round 1's `self_check`). Grouping pieces differently is allowed; making one unreachable is not.
- **Jev picks; local code only checks.** Every pick is checked to be byte-exact at every step. The whole copy is
  pasted with outer line breaks stripped. The whole copy (`source_document`) and the production-shaped
  `target_context` are in the state at every step.

## Design levers you own (compare them by the numbers, then freeze one design at GATE A)
- **D1: grouping and first-step fineness.** Round 1 offered only lines and paragraphs at step 1 when a copy was
  long, which forced the containment judgment. Try offering fine pieces early, e.g. every token run of every line,
  alongside the containers, across **several choice questions in one request** plus a follow-up choice among their
  winners. Justify the choice by hits, calls and latency, not by meaning.
- **D2: option form.** TypeSafe documents options with `null` descriptions that point at text held in `state`
  (`llms-full.txt`, the "point to a line" recipe: `criteria={line_id(i): None ...}`). You measured that the state
  counts **once** across parallel questions (3 × questions at 56.9k tokens OK; 4 × ~71k refused). So pieces held
  once in the state, with id-only options, may let one request carry far more pieces than full-text options can.
  Measure it against full-text options on the same cells.
- **D3: wordings.** Test the instruction's "choose the smallest option that contains all of it" sentence, since it
  may pull toward big pieces and toward the whole copy when two values compete. Also test the whole-copy
  ("everything") option, "nothing fits" and "ask the user". Keep every wording place-neutral.
- **D4: place choice (measure only).** Add one more **choice** in the same request as the first step. It asks what
  the user will paste into `target_context`, with three options: everything that was copied / one part of it /
  nothing of it. Wording is place-neutral and yours to propose. Log its probabilities for every cell and score
  every cell under two policies:
  - **A: Narrowing alone.**
  - **B:** the place choice's pick decides "everything" → the whole copy and "nothing" → No Suitable Match;
    "one part" → Narrowing's result.

  Report both. A known risk: in the free-text spike the equivalent yes/no pulled "About"-type fields to the whole
  résumé, so look at those cells.

## Guarding against tuning to the test set
- **Held-out cells first:** before **any** round-2 Jev call, write and commit **at least 12 new synthetic cells**
  that no round-1 run has seen, with new texts and new target contexts. Include at least 2 per failure class above,
  plus at least 2 ordinary positives and 2 traps, all in the fixture style (production-shaped `target_context`,
  pure values, synthetic names). They are scored separately and **never used for tuning**.
- **Exploration** of D1–D4 runs only on round-1 cells (≤ 150 billed calls). Name every cell you tuned on.
- **GATE A freezes** the design and every wording. After that, a change is an `ask` to the supervisor, and a
  change means re-running everything it affects.

## Where you work
- Worktree `~/.pi/worktrees/jevpaste/narrowing-spike`, branch `spike/narrowing` (round 1's worker has finished and
  pushed; `git pull` first). Everything new goes under `spikes/narrowing/round2/` (code, cells, `results/`,
  `FINDINGS.md`). Import round-1 modules; don't modify round-1 results. Spike branches are never merged.
- Jev via the Gateway as in round 1 (`set -a; . ~/.config/jevpaste/env; set +a`). The free tier returns 429 with
  `retry-after`: pace, and keep the runner resumable per cell (round 1's `run.py` is.)
- **Budget: at most 700 billed Jev calls for round 2** (the whole spike stays ≤ 900). Stop and `ask` if you approach it.
- Parallel requests are allowed (production can send several at once). Report **per-paste latency** as the sum
  over steps of the slowest call in each step; report 429 waits separately, since the free tier inflates them.

## Steps
1. Read: the round-1 report on #49, `spikes/narrowing/FINDINGS.md`, this brief, the #47 resolution. Write and
   commit the held-out cells (`round2/heldout.py`) **before any Jev call**. `send` the cell list.
2. Exploration of D1–D4 on round-1 cells (≤ 150 calls): a table per lever of hits, calls and latency.
3. **GATE A** (`ask`): the frozen design, **every wording verbatim** (step question, follow-up, whole copy,
   nothing fits, ask the user, the place choice), expected calls per paste, the size model, and the tuned-on cells.
   The supervisor checks every wording for field and place vocabulary before approving.
4. Matrix: every round-1 cell (65) **and** the held-out cells, **2 runs each**, under policies A and B. Per paste,
   record per step: option and question counts, the choice, p(choice), p(everything), p(nothing), p(ask), and the
   place-choice probabilities. Also record calls, latency (cold/warm), hit (byte-exact) and the chooser list.
5. `round2/FINDINGS.md`: the verdict against **each** of the 7 criteria by name, for policies A and B, and for
   round-1 cells vs held-out cells separately. Include every miss by name with what Jev chose instead, the design,
   all wordings verbatim, latency (median/p90), calls and cost. Tag **[measured]** / **[inference]**. **Data only —
   no product decision.** Commit, then `git push origin spike/narrowing`.
6. Report comment on #49 (`gh issue comment 49 --body-file <file>`): the verdict table, the misses, branch + commit.
7. **Last step, mandatory:** `intercom send <id> "[narrowing-r2] done — <verdict A> / <verdict B> <comment URL>"`.

## Rules
- Read-only outside `spikes/narrowing/round2/`. Never touch `main`, Swift sources or other worktrees.
- 429 → wait and continue; 401 → stop and `ask`. A background runner dies only with `pkill -9 -f <script>`.
- A failing criterion is a result: report it; don't silently change the design after GATE A.
