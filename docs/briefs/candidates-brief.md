# Brief — Implement Candidate derivation (issue #19)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/candidates`, branch `candidates` (forked from `main` at bef15f9). Your supervisor is the
Pi session with intercom id **`01a0ca65`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly
that id. Daniel (owner) speaks through the supervisor. Two other workers run in parallel on sibling
slices — do not touch their modules.

Communication protocol:
- `intercom send 01a0ca65` one line after every numbered step: `[candidates] step N done — <fact>`.
- `intercom ask 01a0ca65` (blocking) at each **GATE**; prefix the message with `[candidates]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 19` — your ticket. Claim it: `gh issue edit 19 --add-assignee @me`.
2. `gh api repos/DanielMulec/jevpaste/issues/comments/5782480932 --jq .body` — the **state-machine report**:
   the port shapes you implement against and the obligations for your slice. Do not change Core ports;
   if a port shape truly cannot work, `ask` before touching Core.
3. The Core sources: `Sources/SmartPasteCore/Seams/*.swift`, `Sources/SmartPasteCore/Values/*.swift`,
   `docs/design/paste-attempt-state-machine.md`.
4. `gh issue view 16 --comments` (slice plan + acceptance), `gh issue view 1` **Notes** (hard rules:
   400 lines/file incl. tests; no secrets in source; no payloads in diagnostic logs; verbatim excerpt only;
   refer to issues by title), `CONTEXT.md` (vocabulary), `docs/quality-gate.md`, `Makefile`.
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. `make check` green before every commit.
- ≤ 400 lines per file, split by concern. Descriptive names from the glossary. No new dependencies without `ask`.
- Remove the `// periphery:ignore` comments in Core **only** on the properties your adapter now reads (listed in the report).
- Commit small on `candidates`; push after each gate. Do not merge.

## Scope
`Sources/SmartPasteCore/Candidates/` + `Tests/SmartPasteCoreTests/Candidate*Tests.swift` only. Implement
`CandidateExtraction` (both methods) as a pure, deterministic rule set per
`gh issue view 7 --comments` (last comment) and the spike findings:
`git show origin/spike/jev-contract:spikes/granularity/FINDINGS.md`.

## Steps
1. Write `docs/design/candidate-derivation.md` (≤ 80 lines): the derivation rules (lines; `Label: value`
   values as their own candidates plus the whole line; trimming rules; dedup of identical text; ≤ 255 cap and
   which candidates are dropped first), the same-type detection rules (email, URL, phone, handle, …) with
   the regexes you intend, and the test list. **GATE A**: ask with the path.
2. Implement TDD. Every Candidate must be a byte-exact contiguous substring of the source (test it against
   `PasteResultValidation`). Multi-line sources, CRLF, tabs, Unicode, empty and whitespace-only lines, 1 000-line
   sources (cap), `Label: value` with URLs containing colons — all tested.
3. Wire nothing into the app. Proof = the test suite.

## Final steps (after the slice steps above)
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files, and the proof evidence named above.
- Post a report comment on issue #19: what was built, test count, proof evidence, deviations, open questions. **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`[candidates] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
