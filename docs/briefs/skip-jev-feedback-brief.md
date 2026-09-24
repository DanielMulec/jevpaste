# Advisor brief — "Skip Jev when the target gives it nothing to reason about"

**Role:** advisor, read-only. Do not edit files, do not run `make`, do not create branches. Answer once, then
send it to the supervisor (last step, mandatory).

## Read first
- `CONTEXT.md` (glossary: Direct Paste, Smart Paste, Candidate, Candidate Chooser, No Suitable Match)
- `docs/design/direct-paste.md`, `docs/design/jev-gateway.md` (what is sent to Jev, exact question wording)
- `docs/design/mac-interop.md` § TargetResolver → "Target Context" (what is collected, surrounding text always)
- `gh issue view 1 --json body -q .body` → "## Notes" hard rules, especially:
  "Paste Result is one exact, contiguous, verbatim excerpt", "Failures must have a visible indicator, never
  silent failure. No automatic unmodified-source fallback on failed smart paste", "the app chooses *which*
  text, never authors text", "chooser triggered locally by same-type candidates".
- `gh issue view 35` (the ticket), `gh issue view 33 --comments` last comment (evidence: Jev answers
  none_of_these for everything in unlabelled targets), `gh issue view 32 --comments` last comment (Rule 1).

## Situation
⌘⇧V sends the copied text, the focused field's context (label, placeholder, heading, sibling labels,
surrounding screen text) and exact-excerpt candidates (lines, `Label: value` values, paragraphs, sections,
whole item) to Jev. Jev picks the one excerpt that is "the value belonging in that field" or answers
none_of_these. Today a **single-line** item skips Jev ("Direct Paste": whole item, plain ✓). In targets with
no label/placeholder/heading (ChatGPT composer, bare textarea, shell prompt) Jev says none_of_these for
everything, so **multi-line** items never paste there — the user sees "No suitable match".

Daniel (owner) wants this user-friendly enough to share publicly (LinkedIn showcase: "built to get to know
Jev and Opus 5.5"). He is weighing:

- **A)** Run Jev; on none_of_these, loudly fall back to Direct Paste of the whole item automatically.
- **B)** Run Jev; on none_of_these, loudly say so and ask the user to press plain ⌘V themselves.
- **C)** Something else. The supervisor sees:
  - **D)** decide *before* calling Jev: if the target exposes no label/placeholder/heading/sibling labels
    ("Unlabelled Target"), Direct Paste immediately — zero latency, nothing leaves the Mac.
  - **E)** on none_of_these, open the existing Candidate Chooser with the whole item preselected, so one
    Enter pastes whole — never silent, never automatic, exact-excerpt preserved.
  - **F)** reword the Jev questions from "the value belonging in that field" to "what the user would paste
    here", and add app name / bundle id / window title to the context, so Jev itself can choose the whole
    item for a chat composer — no local heuristic.
  - **G)** combinations, e.g. D for unlabelled targets + E when Jev abstains in a labelled target.

Daniel also proposes sending **app name, bundle id and window title** to Jev in addition to today's context.

## Deliver (≤ 600 words, plain prose for a non-technical reader on a phone)
1. Your ranked recommendation with reasons.
2. The strongest objection to each of A, B, D, E, F — cite the rule text you rely on.
3. Any option none of us saw.
4. Whether app name / bundle id / window title are worth sending, and any privacy caveat.
Be concrete and opinionated. Do not hedge everything.

## Last step — mandatory
Send the full answer with `intercom send 01a0d4f1-5b32-7477-8f04-c6ecd0a23d37 "<answer>"` (write the
answer to `/tmp/skip-jev-feedback.md` first and send its contents). Then stop. If you do not send it, the
supervisor waits forever.
