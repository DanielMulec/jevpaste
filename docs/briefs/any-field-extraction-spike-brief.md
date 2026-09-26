# Worker brief — Spike: can Jev extract the excerpt for any field, or does it need an LLM?

Ticket: [Spike: can Jev extract the excerpt for any field, or does it need an LLM?](https://github.com/DanielMulec/jevpaste/issues/46)
(AFK task; **read the ticket body and both its comments** — fixture additions and Daniel's preference).
Decision it serves: [Choose how JevPaste finds the excerpt for any field, not only whole lines](https://github.com/DanielMulec/jevpaste/issues/31#issuecomment-5844214504)
— read that comment first. Glossary: `CONTEXT.md` (**Candidate**, **Embedded Value**, Target Context, Direct Paste).
You are `anthropic/claude-opus-5-5:medium`. Supervisor intercom id: **`01a0dc7c-9fdd-73bd-9ff8-6edd835beae1`**.
Protocol: `intercom send <id> "[any-field] step N done — <fact>"` after each numbered step below; `intercom ask` when
something blocks you. Never sign up for anything; never print `~/.config/jevpaste/env` or any auth file.

## The idea you are measuring (Daniel: "that's what we should 100% try")
Jev is a chooser, not a writer: it can only pick from options we hand it. Today's Candidates are whole lines,
`Label: value` values, paragraphs, sections, the whole item — so for the item below and a **Vorname** field,
`Daniel` is never offered and Jev must say *none of these*. **Engine J** fixes that in two stages, both Jev:
- **Stage 1** (today's call shape + one new boolean): choice question over the structural Candidates
  ("which belongs in the target, or contains what belongs there?") **plus** a boolean `contains_more`:
  "does the chosen Candidate contain *more* than what belongs in the target?" (your wording — record it verbatim).
- **Stage 2** (only when stage 1 chose a Candidate and `contains_more` is high): choice question over the
  **spans** of that Candidate — every contiguous run of its tokens, tokens bounded at whitespace and at
  `, ; : ( ) " ' < > /`, ≤ 12 tokens per span, byte-exact slices, ≤ 254 options (drop longest first) + `none_of_these`.
  Jev picks the exact excerpt.
- **Alternative form J′** (run only if the batched stage-2 choice is unreliable on ≥ 3 cells): per-span boolean
  "is `<span>` the <field>?" — report its hit rate and call count next to J.
**Engine L** (LLM extractor) runs **only on the cells J misses or gets ambiguous** — a rescue check, not a second
matrix (Daniel strongly prefers J; L costs a second provider and a rename).

## Where you work
- Worktree `~/.pi/worktrees/jevpaste/any-field`, branch `spike/any-field-extraction` (already checked out, forked
  from `spike/jev-contract` so the Python helpers exist — do not create another branch). Spike branches are
  **never merged**; no `make check`, no Swift.
- Reuse `spikes/abstention/jev.py` (stdlib client, pacing, never prints the key) and the request shape in
  `spikes/free-text/run.py` (three questions in one call; `target_context` keys `app_name`, `window_title`,
  `field_label`, `placeholder`, `section_heading`, `sibling_field_labels`, `surrounding_text`; absent = omitted).
  Put everything new in **`spikes/any-field/`**: `run.py`, `fixtures.py`, `spans.py`, `analyze.py`,
  `FINDINGS.md`, `results/raw.jsonl`. Log every request/response verbatim.
- Jev key: `set -a; . ~/.config/jevpaste/env; set +a`. Free tier ≈ 1 call/s. **Budget ≤ 320 billed Jev calls.**
- Structural Candidates: mirror `docs/design/candidate-derivation.md` rules 1–8 in Python (lines, `Label: value`,
  paragraphs, sections, whole item; byte dedup). Keep it faithful — the result must transfer to Swift.

## Fixtures (synthetic only — invented names, no real person's data) — `fixtures.py`
Five items, each a list of `(field_label, sibling_labels, section_heading, expected_excerpt | None)` cells:
1. **Address block** (Daniel's motivating case), one value per line, **no labels**:
   `Mira Holzner` / `Prankergasse 77` / `Top 11` / `8020 Graz` / `Österreich` / `mira.holzner@example.org` /
   `https://www.miraholzner.example` / `06608405534`. Fields: Vorname→`Mira`, Nachname→`Holzner`,
   Straße→`Prankergasse`, Hausnummer→`77`, Adresszusatz→`Top 11`, PLZ→`8020`, Ort→`Graz`, Land→`Österreich`,
   E-Mail, Website, Telefon (whole lines), and **Straße und Hausnummer**→`Prankergasse 77`.
2. **Email signature** with prefixes inside lines: `Kind regards,` / `Jonas Prell · Product Lead` /
   `Phone +43 1 2345678 · Mobile +43 660 1112233` / `jonas.prell@example.com | www.prell.example` /
   `IBAN AT61 1904 3002 3457 3201`. Fields: First name, Last name, Job title, Phone, Mobile, Email, Website, IBAN.
3. **Résumé header + About**: name line, `Born 14 March 1991 in Linz`, `Nationality: Austrian`, a 3-line About
   paragraph, then an EXPERIENCE section. Fields: Full name, Birthdate→`14 March 1991`, Birthplace→`Linz`,
   Nationality→`Austrian` (the labelled value — already a Candidate), About→the paragraph, Country.
4. **Order confirmation**: `Order 4711 for wren.castellan@example.net`, `Ship to: Lise Adler, Hauptstr. 5, 4020 Linz`,
   `Total EUR 129,90`, `Tracking DHL 00340434161234567890`. Fields: Email, Order number→`4711`, Recipient
   name→`Lise Adler`, Street→`Hauptstr. 5`, Postal code, City, Amount→`129,90` (also try `EUR 129,90`, note which
   Jev picks), Tracking number.
5. **Profile bio**: two paragraphs of free prose with a handle `@mira_h`, a city mention, a birth year.
   Fields: Handle, City, Bio→paragraph 1 or both (note which), Birth year.
Include **negative cells**: a field whose value is not in the item (e.g. Passwort, Fax) → expected `none_of_these`.
Every cell's `target_context` gets realistic siblings/section/surrounding text (~300–1200 chars, form-like).
Same wording rules as production: `app_name` "Google Chrome", `window_title` a form title.

## Runs and measurements
- **2 runs per cell** for J (stage 1 always; stage 2 when triggered). Per cell record: stage-1 choice + its
  probability, `contains_more` probability, `free_text` (keep production's third question, unchanged), whether
  stage 2 ran, stage-2 choice + probability, span count offered, **hit** (chosen text == expected, byte-exact),
  latency per call (cold/warm), billed calls.
- **Chooser noise:** for stage 2, count how many other spans of the *same type as the winner* would trigger the
  production same-type chooser (`docs/design/candidate-derivation.md` "Same-type detection"); a span with no type
  never triggers it. Report per cell.
- **Gate correctness:** cells whose expected excerpt is a whole Candidate should see `contains_more` low;
  cells needing a sub-span should see it high. Report a 2×2.
- **L rescue** (only the cells J missed/ambiguous, 1 run each, ≤ 40 calls per model): prompt = the item + the same
  target context, instruction "return exactly one contiguous substring of the item that belongs in this field,
  verbatim, or NONE" as JSON; verify byte-exact substring locally. Models via the Vercel AI Gateway
  OpenAI-compatible endpoint (`https://ai-gateway.vercel.sh/v1/chat/completions`, same key):
  `deepseek/deepseek-v4.1-flash`, `openai/gpt-6-luna`. Daniel has **no Gateway credits**: on 402/403/429 that
  persists after 3 paced retries, stop that model and record it. Fallback for Luna only: if `codex` is installed
  on this Mac (`which codex`), `codex exec -m gpt-6-luna --json` with the same prompt (Daniel's own login —
  approved for the spike); measure its full-turn latency. If not installed, record "not measured". Never log in.

## Pass criteria for J (fixed by Daniel — report against them, do not move them)
- Address block, signature, résumé: J hits the expected excerpt on **every** listed field in **both** runs.
- `contains_more` fires correctly on every cell (2×2 has empty off-diagonals).
- Negative cells end in `none_of_these`.
Report misses by name with what Jev chose instead; the full table either way.

## Deliverables
1. `spikes/any-field/FINDINGS.md`: setup, exact wording of every question, the per-cell table, the 2×2, latency
   summary (stage 1, stage 2, J total per paste), chooser-noise counts, J′ if run, L rescue table, call count and
   cost. Tag claims **[measured]** / **[inference]**. **No product decision** — data only.
2. Commit on `spike/any-field-extraction` and `git push -u origin spike/any-field-extraction`.
3. **Report comment** on the ticket (`gh issue comment 46 --body-file <file>` — write the body to a file):
   verdict against the criteria, the comparison table, branch + commit hash, open questions.
4. **Last step, mandatory:** `intercom send 01a0dc7c-9fdd-73bd-9ff8-6edd835beae1 "[any-field] done — <verdict> <comment URL>"`.

## Rules
- Read-only outside `spikes/any-field/`. Do not touch Swift sources, `main`, or other worktrees.
- 429 → wait and continue; 401 → stop and intercom the supervisor. Key rejected by the Gateway for L → record, move on.
- Ambiguous cells (is `Prankergasse 77` or `Prankergasse` the "Straße"?) stay in, marked "borderline", with what Jev did.
- Send step reports at: (1) fixtures + span rules written, (2) J smoke call OK, (3) J matrix done with hit counts,
  (4) L rescue done or skipped, (5) findings pushed.
