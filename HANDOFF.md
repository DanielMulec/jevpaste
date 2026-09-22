# Handoff — jevpaste (Wayfinder map in progress)

Repo: `/Users/danielmulec/Projekte/experiments/jevpaste` (private, `DanielMulec/jevpaste`, `main`).
Owner: Daniel Mulec. Tracker: GitHub Issues with native sub-issues + blocking dependencies
(`gh` authenticated; blocking edges via GraphQL `blockedBy`, wiring via `addSubIssue` /
`addBlockedBy` mutations with the `sub_issues` / `issue_dependencies` GraphQL-Features headers).

## Where things stand

Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1).
Read its body first (Destination, Notes = hard rules, Decisions-so-far index, fog, out-of-scope).
Do not restate it here. Glossary: `CONTEXT.md` — keep it updated when terms sharpen.

Twelve tickets closed, each with a resolution comment. The ones the next steps lean on:
[Choose paste lifecycle, cancellation and clipboard preservation](https://github.com/DanielMulec/jevpaste/issues/8#issuecomment-5767988662)
(Paste Attempt state model + test list) and
[Choose native module boundaries and local quality checks](https://github.com/DanielMulec/jevpaste/issues/10#issuecomment-5781286644)
(five modules, seams, gate, review policy; ADR `docs/adr/0001-…md`).

**Frontier (open, unblocked):**
- [Define the implementation slices and their order](https://github.com/DanielMulec/jevpaste/issues/16) — grilling, HITL. Recommended next: it turns the scaffold into a build plan. Consult the two prototype tickets' questions before fixing the shell slice.
- [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14) — prototype; can now be done against the real `JevPaste.app` skeleton or the old probe signed with `jevpaste-dev`.
- [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9) — prototype, HITL.

Most recent closed: [Scaffold the package, quality gate and signed bundle](https://github.com/DanielMulec/jevpaste/issues/15#issuecomment-5781770345) — merged to `main` (8ba350d). `make check` is the gate (read `docs/quality-gate.md`), `make install` produces the signed app, pre-commit hook is installed in the shared `.git/hooks` (applies to every worktree). Signing keychain: password in `~/.config/jevpaste/signing-keychain-password`, key+cert in `~/.config/jevpaste/signing/`; if `make app` fails on unlock, run `scripts/restore-signing-keychain.sh`. The app has **no Accessibility grant yet**.

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
6. A worker's blocking `intercom ask` is answered **only** by `intercom reply` — a `herdr agent prompt` just queues behind it and the worker looks stuck. `intercom send` silently attaches to a pending ask, so use it only when none is pending.
7. **There is no `/alias` command in this pi.** Give the worker the supervisor's intercom id
   explicitly in the brief (two pis may share the cwd).
8. Communication protocol Daniel likes: the worker owns one channel to Daniel (its pane), asks
   him for one-word answers (`done`/`nothing`/`failed`); gated steps via blocking intercom
   `ask` to the supervisor; matrix-row reports after each; ask before anything unexpected.
   Review the worker's code early. **Never block in a long `sleep`** while a worker runs — its intercom asks only land when this session has a free turn; poll ≤ 60 s or just wait for messages.

Accessibility grants need a human click in System Settings (no CLI path; this terminal has no AX
trust for UI scripting). Brief workers to park cleanly at that step if Daniel is away.
Reference brief: `docs/briefs/scaffold-brief.md` (gates, report format).

## Standing facts — do not re-litigate

- **Hard rule:** Paste Result = one exact contiguous verbatim excerpt. Never rewrite, combine,
  reformat, generate. No "safety" argument licenses mutating it.
- Jev returns typed decisions, not text (contract in the Jev semantics ticket; spike on `spike/jev-contract`).
- Free-tier Jev ~1 call/s account-wide. 400 lines/file ceiling. No hosted CI.
- Toolchain: no Xcode, CLT only, Swift 6.3.3. `swift test` works via the swift-testing package +
  two linker flags; SwiftLint needs `TOOLCHAIN_DIR=/Library/Developer/CommandLineTools` (not
  `--disable-sourcekit`). All of it is wired in the Makefile — just run `make check`; run `npm ci`
  once per checkout first.
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

- Worktrees under `~/.pi/worktrees/jevpaste/{jev,macos,quality,spike-contract,macos-probe,signing,scaffold}` — all branches pushed; `scaffold` is merged and removable.
- Herdr: `wC:pA` (`signing-worker`, Opus 5, done) and `wC:pC` (`scaffold-worker`, Opus 5.5, done) — closable. `wC:pB` is the `/teach` session — keep. `wC:p7` is an older idle pi (grok) in the repo cwd; closable. Supervisor intercom id for this session was `01a0c5fd`; a new supervisor must give the worker its new id explicitly (two pis share the cwd, so "find by cwd" is ambiguous — and `intercom send` will silently attach to a pending ask, so answer asks with `reply`).
- `/tmp/jevpaste-signing/` still holds the original signing key until reboot (copy lives in `~/.config/jevpaste/signing/`); `/tmp/jevtestprobe`, `/tmp/jevverify` are disposable.

## Suggested skills

- `wayfinder` (every session), `grilling` + `domain-modeling` (the slicing ticket),
  `codebase-design` (when a slice touches a seam), `prototype` (the two prototype tickets),
  `pi-intercom` + `herdr --skill` (workers), `research` (only for new research tickets),
  `tdd` (once slices are implemented — the lifecycle ticket already holds the test list).
