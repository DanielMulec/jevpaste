# Worker brief — Spike: does Jev reliably tell free-text places from value fields?

Ticket: [Spike: does Jev reliably tell free-text places from value fields?](https://github.com/DanielMulec/jevpaste/issues/40)
(AFK task). Decision it serves: [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35#issuecomment-5821465655)
— read that comment first. Glossary: `CONTEXT.md` (**Free-text Target**, Direct Paste, Target Context).

## Where you work
- Worktree `~/.pi/worktrees/jevpaste/spike-contract`, branch `spike/jev-contract` (already checked out — do not
  create a new branch; commit on this one). Spike branches are **never merged**; no `make check`, no Swift.
- Existing code: `spikes/abstention/{run.py, jev.py, candidates.py, sources.py, analyze.py, FINDINGS.md}`.
  Reuse `jev.py` as is (stdlib client, pacing, never prints the key). Put the new spike in
  **`spikes/free-text/`** with its own `run.py`, `situations.py`, `analyze.py`, `FINDINGS.md`, `results/raw.jsonl`.
- Key: `set -a; . ~/.config/jevpaste/env; set +a` — never print, log or commit it. Free tier ≈ 1 call/s;
  keep `jev.py`'s pacing. Budget: ≤ 60 billed calls (10–12 situations × 3 runs + a few smoke calls).

## What one call must look like (mirror the production request in `docs/design/jev-gateway.md`)
```
state = { "source_document": <one fixed multi-line document>,
          "target_context": { "app_name", "window_title", "field_label", "placeholder",
                              "section_heading", "sibling_field_labels", "surrounding_text" } }
questions = {
  "paste":          <existing choice question, verbatim wording from run.py CHOICE_INSTRUCTIONS with
                     `target_field` → `target_context`, options = local candidates + none_of_these>,
  "contains_value": <existing GATE_POSITIVE, same rename>,
  "free_text":      NEW boolean — your job to word it. Intent: "Is `target_context` a free-text place —
                     a chat or message composer, an editor, a document, a terminal — where the user
                     would paste whatever they copied? Or is it a field that expects one specific value?"
                     criteria: true = free-text place; false = a field for one specific value. }
```
Absent/empty context fields are **omitted** from the JSON, as production does.
The three questions ride in **one** call. Log every response verbatim to `results/raw.jsonl`.

## Situations (≥ 10; each with realistic surrounding text ~300–1500 chars; synthetic names only)
Free-text places (expected `free_text` ≥ 0.8):
1. ChatGPT desktop composer — app "ChatGPT", window title a chat title, placeholder "Ask anything" **and**
   a variant **without** the placeholder (we don't know what AX exposes), surrounding = a short chat transcript.
2. Terminal — app "Ghostty", window title a path, no label/placeholder, surrounding = last lines of a shell
   session ending in a prompt.
3. Slack-like message box — app "Slack", title "#general – Acme", placeholder "Message #general", channel chatter.
4. WhatsApp composer — app "WhatsApp", title a contact name, placeholder "Type a message", chat lines.
5. TextEdit document — app "TextEdit", title "Untitled 3", no label, surrounding = the document's text so far.
6. Code editor — app "Code", title "notes.md — project", surrounding = a markdown file.
7. Comment box on a web page — app "Google Chrome", title an article, label "Add a comment", surrounding = article + comments.
Value fields (expected `free_text` ≤ 0.2):
8. Email field — Chrome, title "Sign up – Example", label "Email address", siblings "Full name", "Password".
9. Address form — Chrome, section heading "Shipping address", label "Street", siblings "City", "Postcode".
10. Search box — Chrome, placeholder "Search", surrounding = a results page.
11. Phone field in a native form — app "Contacts", label "mobile", siblings "home", "work".
12. Spreadsheet cell / single-line title field — app "Numbers" or "Finder" rename, short surrounding.

Same multi-line `source_document` for all (a short résumé-like block: name, email, phone, two-line address,
a paragraph). Candidates from `candidates.py` (≤ 20, whole lines + values), plus `none_of_these`.

**3 runs per situation.** Record per run: `free_text` probability, `contains_value` probability, `paste` choice.

## Pass criteria (fixed by Daniel — report against them, do not move them)
- Every free-text situation: `free_text` ≥ 0.8 on **every** run.
- Every value-field situation: `free_text` ≤ 0.2 on **every** run.
Report the full table either way. Also report: min/max per situation, the ChatGPT with/without-placeholder
delta, whether adding `app_name`/`window_title` changed anything (run situations 1 and 8 once more **without**
them), and latency per call vs. the two-question baseline.

## Deliverables
1. `spikes/free-text/FINDINGS.md`: setup, the table, verdict against the criteria (**[measured]** /
   **[inference]** tags like the abstention spike), the exact `free_text` wording used, call count and cost.
2. Commit on `spike/jev-contract` and push (`git push -u origin spike/jev-contract`).
3. **Report comment** on the ticket (`gh issue comment 40 --body-file <file>`; write the body to a file —
   apostrophes break inline bodies): the table, verdict, wording, branch + commit hash, open questions.
4. **Last step, mandatory:** `intercom send 01a0d4f1-5b32-7477-8f04-c6ecd0a23d37 "<verdict + link to the comment>"`.
   If you skip this the supervisor waits forever.

## Rules
- Read-only outside `spikes/free-text/`. Do not touch Swift sources, `main`, or other worktrees.
- If `jev.py` 429s repeatedly, wait and continue; if the key is rejected (401), stop and intercom the supervisor.
- If any situation is ambiguous to *you* (is a comment box free text?), keep it, mark it "borderline" in the
  table, and say what Jev did — the supervisor decides.
- No product decision in FINDINGS.md; data only.
