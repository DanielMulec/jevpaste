# Worker brief — Spike: does choice-only Narrowing pass the any-field matrix?

Ticket: [Spike: does choice-only Narrowing pass the any-field matrix?](https://github.com/DanielMulec/jevpaste/issues/49)
(AFK task; the ticket body holds the **fixed pass criteria** — do not move them).
Decision it serves: [Decide the extraction engine for any-field Smart Paste](https://github.com/DanielMulec/jevpaste/issues/47#issuecomment-5845599979)
— **read that resolution comment first, completely**; it is your contract. Predecessor data:
[the any-field spike report](https://github.com/DanielMulec/jevpaste/issues/46#issuecomment-5845373145) and
`spikes/any-field/FINDINGS.md` on your branch. Glossary: **`main`'s** `CONTEXT.md` — read
`/Users/danielmulec/Projekte/experiments/jevpaste/CONTEXT.md` (your branch holds an older copy): **Narrowing**,
**Candidate**, **Candidate Chooser**, **Embedded Value**, **No Suitable Match**, **Direct Paste**. This brief lives
on `main` too (`docs/briefs/narrowing-spike-brief.md`), not on your branch.
You are `anthropic/claude-opus-5-5:high`. The supervisor's intercom id is in your launch prompt — use exactly that
id. Protocol: `intercom send <id> "[narrowing-spike] step N done — <fact>"` after each numbered step; `intercom ask`
at **GATE A** and whenever something blocks you. Never sign up for anything; never print `~/.config/jevpaste/env`.

## What you are measuring (Daniel's standing rule: everything that can be a Jev choice is a Jev choice)
**Narrowing:** starting from the whole copy, Jev repeatedly chooses among four kinds of option —
1. **the current piece, unchanged** (Jev stops by choosing it: that piece is the paste),
2. **every piece cut from it** (the Candidates),
3. **"nothing fits"** (→ No Suitable Match, at any step),
4. **"ask the user"** (→ the Candidate Chooser; record which options it would list: every option Jev gave any
   probability to, most likely first).

No yes/no question anywhere (`contains_value`, `free_text` and the old `contains_more` gate are gone). No local
rule decides meaning: no heading rules, no `Label: value` detection, no email/phone/URL/handle patterns, no
12-token limit, no drop order, no field or place vocabulary in any wording. A piece with nothing smaller to cut is
final without a call (nothing to choose). The whole copy (`source_document`) is sent at every step; the Target
Context as in production.

## Design you own (report it at GATE A before the matrix)
- **Cutting:** "the scissors cut at every point" — line breaks, spaces, punctuation, and single characters — so
  every contiguous substring is reachable by some sequence of choices (`Innsbruck` inside `Innsbruck.`, `77`
  inside `Prankergasse77`, the cover-letter body of 86 words, a paragraph run across blank lines). You choose
  the levels and how pieces are grouped per step; justify it by reachability and call count, not by meaning.
- **No piece is ever dropped.** Jev allows **255 options per Choice** (documented; 256 is rejected), so a choice
  holds 253 pieces next to "nothing fits" and "ask the user". When a step has more, put several choice
  questions into **one** request (questions run in parallel; no documented count limit) and pick among their
  winners with a follow-up choice — TypeSafe's own recipe ("pick the section first, then the span inside it";
  `https://docs.typesafe.ai/llms-full.txt`, search "255"). Mind the size budget: **64k tokens per request; 32k
  for `state` plus the single longest question**.
- **Options are sent in full** — no 255-character description cut (probed 2026-09-26: 1,500- and 6,000-character
  descriptions accepted and read to the end). You may compare full-text descriptions against TypeSafe's
  id-referenced form (text tagged in `state`, description `null`); pick by the numbers.
- **Wording:** place-neutral. The choice asks what the user means to paste into `target_context`; the whole-copy
  option is described to Jev as everything that was copied, as it is. **Never name field types or place types**
  in instructions, criteria or examples (a worked example saying "postcode" or "chat box" got a whole wording
  withdrawn last time). The supervisor checks every wording at GATE A.

## Where you work
- Worktree `~/.pi/worktrees/jevpaste/narrowing-spike`, branch `spike/narrowing`, forked from
  `origin/spike/any-field-extraction` (so `spikes/any-field/`, `spikes/free-text/`, `spikes/abstention/jev.py`
  exist). Everything new goes into **`spikes/narrowing/`** (`run.py`, `cuts.py`, `analyze.py`, `FINDINGS.md`,
  `results/raw.jsonl`). Spike branches are **never merged**; no Swift, no `make check`.
- Reuse the any-field fixtures and helpers (import, don't copy). Log every request and response verbatim.
  Make the runner **resumable per cell** (laptop lids and train tunnels kill sessions; resume by row count).
- Jev via the Gateway as in the any-field spike (`set -a; . ~/.config/jevpaste/env; set +a`). Free tier: expect
  429s with 60 s `retry-after`; pace and resume. **Budget ≤ 900 billed Jev calls** (the last spike cost $0.018
  for 291). No LLM calls — the LLM engine is dropped.

## Cells (synthetic only)
1. **All 56 cells** of `spikes/any-field/fixtures.py` (12 traps), with their accepts and borderline marks.
2. **Whole-copy places:** the free-text places of `spikes/free-text/` (Chrome textarea, Herdr terminal prompt,
   ChatGPT composer, WhatsApp composer) with a **multi-line** item → the whole copy; the résumé's "Notes" cell.
3. **Chooser cells:** the two-emails ticket (T01) and the contract spike's three-equal-emails case (find it in
   `spikes/*/FINDINGS.md` on this branch: "3 emails → 0.91–0.95") → "ask the user"; Phone and Mobile on the
   signature → **no** ask.
4. **New cells:** `Mira Holzner, Prankergasse 77, 8020 Graz` as a single-line item into "Ort" → `Graz`; a
   single-line URL into a chat composer → the whole URL; a copy with **more than 253 pieces** at its first step
   (e.g. a 300-line list with the wanted value deep inside) → hit; a copy **too big for one call** (state +
   question over the budget) → record Jev's exact status code and error body and the size where it starts, so
   the build can show "Too long for Smart Paste — ⌘V pastes it whole".

## Steps
1. Cutting + grouping + wordings written; offline reachability: every expected excerpt reachable (list any that
   is not). `send`.
2. **GATE A** (`ask`): the design above, every wording verbatim, expected calls per paste. Wait for approval.
3. Smoke: 5 cells, 1 run. `send` the hits and calls per paste.
4. Matrix: **2 runs per cell**. Per paste record: each step's options count, choice, probability, "ask"/"nothing
   fits" probabilities, calls, latency per call and per paste (cold/warm), hit (byte-exact), chooser list.
   Tuning, if any, happens on ≤ 6 named cells, marked as tuned in the table (there is no held-out set).
5. `FINDINGS.md`: verdict against **each** of the 7 fixed criteria by name, the per-cell table, the design, all
   wordings verbatim, latency (median/p90 per paste), calls and cost, the too-big response. Tag **[measured]** /
   **[inference]**. **Data only — no product decision.** Commit, `git push -u origin spike/narrowing`.
6. Report comment on the ticket (`gh issue comment 49 --body-file <file>`): verdict table, misses by name with
   what Jev chose instead, branch + commit.
7. **Last step, mandatory:** `intercom send <id> "[narrowing-spike] done — <verdict> <comment URL>"`.

## Rules
- Read-only outside `spikes/narrowing/`. Never touch `main`, Swift sources or other worktrees.
- 429 → wait and continue; 401 → stop and `ask`. Killing a background runner needs `pkill -9 -f run.py`.
- A failing criterion is a result, not a reason to change the design silently: report it; the supervisor brings it
  to Daniel before any Swift.
