# Brief — Implement the JevGateway adapter (issue #21)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/jev-gateway`, branch `jev-gateway` (forked from `main` at bef15f9). Your supervisor is the
Pi session with intercom id **`01a0ca65`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly
that id. Daniel (owner) speaks through the supervisor. Two other workers run in parallel on sibling
slices — do not touch their modules.

Communication protocol:
- `intercom send 01a0ca65` one line after every numbered step: `[jev-gateway] step N done — <fact>`.
- `intercom ask 01a0ca65` (blocking) at each **GATE**; prefix the message with `[jev-gateway]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 21` — your ticket. Claim it: `gh issue edit 21 --add-assignee @me`.
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
- Commit small on `jev-gateway`; push after each gate. Do not merge.

## Scope
`Sources/JevGateway/` + `Tests/JevGatewayTests/` only. Implement `DecisionService` against Vercel AI Gateway's
Jev surface exactly as spiked: `gh issue view 7 --comments` (last comment) and
`git show origin/spike/jev-contract:spikes/context/` (request/response JSON shapes — read the scripts and
FINDINGS.md; `git ls-tree -r origin/spike/jev-contract --name-only | grep spikes/` to find them).

## Rules specific to this slice
- The key is read at runtime from `~/.config/jevpaste/env` (`AI_GATEWAY_API_KEY=`) for now; a Keychain move
  is a later ticket. Never log, print, or commit it. A missing key → `.failed` with a diagnostic that names the
  file, not the value.
- No payloads (source document, target context, candidates) in any log. No retry, no timeout in the adapter:
  map HTTP 429 (+ `retry-after`) to `.rateLimited(retryAfter:)`, any other error to `.failed`. Call `reply`
  exactly once, on the main actor.
- Unit tests use an injected `URLProtocol`/transport stub — no network. One **live test** behind an env
  flag (`JEVPASTE_LIVE_JEV=1`) that makes a single real call with a synthetic document; it must be skipped
  (not failed) when the flag or the key is absent, so `make check` stays offline.
- Free tier ≈ 1 call/s account-wide; run the live test at most a handful of times.

## Steps
1. `docs/design/jev-gateway.md` (≤ 80 lines): request JSON (both batched questions), response parsing, the
   mapping table to `DecisionReply`, error taxonomy, transport seam for tests. **GATE A**: ask with the path.
2. Implement TDD (transport stub): happy path, `none_of_these`, boolean gate, 429 with/without `retry-after`,
   malformed JSON, out-of-range choice index, missing key.
3. Run the live test once (`JEVPASTE_LIVE_JEV=1 swift test --filter ...` with the linker flags from the
   Makefile). Proof = its output line with latency; do not paste the request body.

## Final steps (after the slice steps above)
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files, and the proof evidence named above.
- Post a report comment on issue #21: what was built, test count, proof evidence, deviations, open questions. **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`[jev-gateway] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
