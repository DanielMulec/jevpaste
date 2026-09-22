# Brief — Implement the Paste Attempt state machine over the seams (issue #18)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/state-machine`, branch `state-machine` (forked from `main`). Your supervisor
is the Pi session with intercom id **`01a0ca65`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks through the supervisor.

Communication protocol:
- `intercom send 01a0ca65` one line after **every numbered step**: `step N done — <fact>`.
- `intercom ask 01a0ca65` (blocking) at each **GATE**; do not continue until answered.
- Anything unexpected (tool crash, install prompt, design fork not covered here) → `ask` first.
- Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never read `~/.config/jevpaste/env`. No network at runtime.

## Read first (in this order)
1. `gh issue view 18` — your ticket. Claim it: `gh issue edit 18 --add-assignee @me`.
2. `gh issue view 8 --comments` — the **lifecycle resolution**. It is the spec, including the
   deterministic test list at the bottom. Do not re-decide anything in it.
3. `gh issue view 7 --comments` — Jev contract (what `DecisionService` returns: a typed decision —
   chosen Candidate or `none_of_these`, plus the boolean gate — never text).
4. `gh issue view 10 --comments` and `docs/adr/0001-*.md` — module boundaries; Core imports nothing
   platform-specific (the lint enforces this).
5. `gh issue view 16 --comments` — the slice plan and acceptance for this slice.
6. `gh issue view 1` **Notes** — hard rules (400 lines/file incl. tests; verbatim excerpt only; no
   secrets; refer to issues by title). `CONTEXT.md` — use its vocabulary in type and method names.
7. `docs/quality-gate.md` and the `Makefile` — `make check` is the gate. Run `npm ci` once first.
8. Skills: read `~/.agents/skills/tdd/SKILL.md` and `~/.agents/skills/codebase-design/SKILL.md`.

## Scope
Only `Sources/SmartPasteCore` and `Tests/SmartPasteCoreTests`. You are the **single writer** that
gives the six seam protocols their real shapes; every later slice implements against what you fix,
so keep the protocols minimal, `Sendable`, and named from the glossary. Adapters (`MacInterop`,
`JevGateway`, `HistoryStore`) and `JevPasteApp` stay untouched except the trivial edits needed to
keep their placeholder conformances compiling — ask first if more than that is needed.

Deliver the Paste Attempt as a pure, deterministic state machine driven by injected ports:
clock/timer, clipboard, target resolver, decision service, inserter, hotkey, plus an outcome
presenter port (how the shell learns what to show: processing at 150 ms, ✓, reason, chooser,
restore-not-done note). Candidate derivation and pre-check *rules* are later slices — take a
`Candidate` list and a pre-check result through simple injected functions/protocols with stub
implementations in tests. Candidate Chooser is a port too (async choice / cancel), off the clock.

## Rules
- TDD, red-green-refactor, in the order of the ticket's test list. Every test in that list exists
  by name and passes. Swift Testing (`import Testing`).
- Swift 6 strict concurrency; `@MainActor` where the coordinator needs it; no `Task.sleep` in tests —
  the clock is a port.
- Verbatim-substring validation of the Paste Result before delivery is in Core and tested.
- ≤ 400 lines per file. Split by concern (state, transitions, ports, delivery step, tests per
  scenario group), not arbitrarily. Descriptive names, no abbreviations.
- Commit small and descriptive on `state-machine`; push after every gate.

## Steps
1. Read everything above; write `docs/design/paste-attempt-state-machine.md` (≤ 120 lines): the
   port protocols you intend (signatures), the state/transition table, and where the 5 s clock
   starts/stops. **GATE A**: ask with the path. Wait — the supervisor reviews the port shapes.
2. Implement ports + state machine TDD through the test list. Send a progress line per test group.
3. `make check` green. **GATE B**: ask with the `swift test` summary line and file line counts
   (`wc -l Sources/SmartPasteCore/**/*.swift Tests/SmartPasteCoreTests/*.swift`).
4. Update `CONTEXT.md` only if a term sharpened (ask first). Push.
5. Post a report comment on issue #18: what was built, test count, port list, open questions for
   the adapter slices. **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
