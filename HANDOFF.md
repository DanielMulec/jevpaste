# Handoff — jevpaste (Wayfinder map in progress)

Repo: `/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main`).
Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking dependencies
(`gh` authenticated; blocking edges via GraphQL `blockedBy`, wiring via `addSubIssue` /
`addBlockedBy` mutations with the `sub_issues` / `issue_dependencies` GraphQL-Features headers).

## Where things stand

Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1).
Read its body first (Destination, Notes = hard rules, Decisions-so-far index, fog, out-of-scope).
Do not restate it here. Glossary: `CONTEXT.md` — keep it updated when terms sharpen.

Nine decisions closed, each with a resolution comment. The most recent:
[Choose paste lifecycle, cancellation and clipboard preservation](https://github.com/DanielMulec/jevpaste/issues/8#issuecomment-5767988662)
— the full Paste Attempt state model, invariants and test list live there.

**Frontier (open, unblocked):**
- [Scaffold the package, quality gate and signed bundle](https://github.com/DanielMulec/jevpaste/issues/15) — task, AFK (Opus 5.5 medium worker pane). Spec is the resolution of the architecture ticket + ADR 0001. Recommended next.
- [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14) — prototype; sign the probe with `jevpaste-dev`.
- [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9) — prototype, HITL.

Blocked: [Define the implementation slices and their order](https://github.com/DanielMulec/jevpaste/issues/16) waits on the scaffold.

Most recent closed: [Choose native module boundaries and local quality checks](https://github.com/DanielMulec/jevpaste/issues/10#issuecomment-5781286644) — five targets, Core owns seams, `make check` composition, SwiftLint policy, reviewer routing chain. ADR: `docs/adr/0001-…md`. Key fact: `swift test` works on CLT with the swift-testing package + `-Xlinker -L/Library/Developer/CommandLineTools/Library/Developer/usr/lib -Xlinker -rpath -Xlinker <same>` (probe in `/tmp/jevtestprobe`, disposable).

**Models (Daniel's standing preference, 2026-09-22):** workers/prototypes `anthropic/claude-opus-5-5:medium` — **Opus 5 is retired, do not use**. Research `deepseek/deepseek-flash`. Pre-merge semantic-duplication reviewer chain: `openai-codex/gpt-5.6-sol:medium` → `xai/grok-4.7` (highest thinking accepted; supervisor reviews Grok's reviews until proven) → `anthropic/claude-opus-5-5:medium`, always a fresh instance separate from the author.

Side session (not on the map): `/teach` on AppKit/SwiftUI roles + Swift 6 concurrency, pane `wC:pB`, agent `swift-teach`, workspace `~/Projekte/education-swift-mac`. Never write teaching files into this repo.

## Running a worker pane (do this exactly; the previous attempt failed twice)

Daniel wants spikes/builds run by **Opus 5.5, thinking medium** (`anthropic/claude-opus-5-5:medium`) in a **separate Pi instance in a
Herdr pane**, not a subagent. Research: DeepSeek Flash.

1. Read `herdr --skill` and `pi --help` first. `intercom … openProjectPaneIfMissing` launches
   pi with the *default* model — do not use it for workers.
2. `herdr pane split --current --direction right --cwd <worktree> --no-focus` → read `pane_id`.
3. `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model anthropic/claude-opus-5-5:medium`
4. Verify: `herdr agent read <name> --source visible --lines 30 | grep -i opus` must show
   `claude-opus-5-5 • medium` before sending anything.
5. `herdr agent prompt <name> "<brief pointer>"` (no `--timeout` without `--wait`).
6. **There is no `/alias` command in this pi.** Don't tell workers to run it; tell them to
   `intercom list` and find the supervisor by cwd.
7. Communication protocol Daniel likes: the worker owns one channel to Daniel (its pane), asks
   him for one-word answers (`done`/`nothing`/`failed`); gated steps via blocking intercom
   `ask` to the supervisor; matrix-row reports after each; ask before anything unexpected.
   Review the worker's code early.

The one human step in the signing spike is the Accessibility toggle in System Settings
(no CLI path without disabling SIP). If Daniel is away, the worker parks there and commits
its partial `SIGNING-RESULTS.md`.

## Standing facts — do not re-litigate

- **Hard rule:** Paste Result = one exact contiguous verbatim excerpt. Never rewrite, combine,
  reformat, generate. No "safety" argument licenses mutating it.
- Jev returns typed decisions, not text (contract in the Jev semantics ticket; spike on `spike/jev-contract`).
- Free-tier Jev ~1 call/s account-wide. 400 lines/file ceiling. No hosted CI.
- Toolchain: no Xcode, CLT only, Swift 6.3.3; `swift build` works, `swift test` does not;
  SwiftLint needs `--disable-sourcekit`.
- Signing: every installed build is signed with `jevpaste-dev` (dedicated keychain
  `~/Library/Keychains/jevpaste-signing.keychain-db`); ad-hoc builds orphan the grant and are
  never installed. `~/Desktop/MacOSProbe.app` (ad-hoc) and `~/Desktop/SigningProbe.app`
  (identity-signed, granted) are evidence — leave them.
- Daniel has given **blanket approval** for Keychain changes, Accessibility grants, toolchain
  installs. Still: synthetic payloads only when pasting into real apps (a probe once wrote into
  his real Notes). Don't nag him with reminders he has dismissed.
- Credentials: Vercel AI Gateway key at `~/.config/jevpaste/env`, mode 600. Never print it.

## Working with Daniel

- Often answers from his phone: short questions, one or two at a time, numbered, with a
  recommended answer. Don't answer for him.
- Wayfinder governs: claim by assignment first; one non-research ticket per session; resolve
  with comment → close → gist on the map → graduate fog → new tickets create-then-wire.
- Refer to tickets by linked title, not bare numbers.

## Loose ends on the Mac (non-blocking)

- Worktrees under `~/.pi/worktrees/jevpaste/{jev,macos,quality,spike-contract,macos-probe,signing}` — all branches pushed.
- Herdr: pane `wC:pA` hosts the finished `signing-worker` (Opus 5, retired model) — closable. `wC:p7` is an older idle pi (grok) in the repo cwd; closable. Supervisor intercom id for this session was `01a0c5fd`; a new supervisor must give the worker its new id explicitly (two pis share the cwd, so "find by cwd" is ambiguous — and `intercom send` will silently attach to a pending ask, so answer asks with `reply`).
- Clipboard may hold a synthetic marker; unsaved TextEdit scratch doc; `test-page.html` open in Chrome.

## Suggested skills

- `wayfinder` (every session), `grilling` + `domain-modeling` (architecture ticket),
  `codebase-design` (architecture), `prototype` (history UX), `pi-intercom` + `herdr --skill`
  (workers), `research` (only for new research tickets).
