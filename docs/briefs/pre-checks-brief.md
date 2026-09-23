# Brief — Implement Pre-check rules (issue #20)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/pre-checks`, branch `pre-checks` (forked from `main`). Your supervisor is the Pi
session with intercom id **`01a0cff5`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly
that id; ignore any other pi in that cwd. Daniel (owner) speaks **only through the supervisor**. **Two parallel
workers exist** (`chatgpt-resolver`, `history-probe`); the installed app and Daniel's attention are shared —
`make install` and any step where Daniel acts is an `intercom ask`, and you wait.

Communication protocol:
- `intercom send 01a0cff5` one line after every numbered step: `[prechecks] step N done — <fact>`.
- `intercom ask 01a0cff5` (blocking) at each **GATE**; prefix with `[prechecks]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 20` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. The decisions the rules come from: `gh issue view 6 --comments` (last comment: "Never stored, never sent",
   "Suspected secrets", "Secrets in target context"), `gh api repos/DanielMulec/jevpaste/issues/comments/5767988662 -q .body`
   (lifecycle §2 local pre-checks: each a visible refusal, zero Jev calls, zero pasteboard writes), and the
   resolution of [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14):
   **no multi-line-on-send-capable-Target rule is needed** — do not add one.
3. `gh issue view 16 --comments` (slice plan + acceptance rules), `gh issue view 1` **Notes** (hard rules:
   400 lines/file incl. tests; no payloads in diagnostic logs; refer to issues by title), `CONTEXT.md`,
   `docs/quality-gate.md`, `Makefile`.
4. Code you will touch: `Sources/SmartPasteCore/Seams/PreCheck.swift`, `Values/PasteAttemptOutcome.swift`
   (`PreCheckRefusal`), `Values/ClipboardItem.swift` (`isConcealed`), `Values/BoundTarget.swift` (`isSecureField`,
   `context`, `surroundingText`), `PasteAttempt/PasteAttemptCoordinator.swift` (`refuse`, where the Decision is
   built), the interim `Sources/JevPasteApp/Interim/SecureTargetAndConcealedItemPreCheck.swift` (you replace it),
   `Sources/JevPasteApp/Indicator/OutcomeMessage.swift` (refusal wording), `Sources/JevPasteApp/SmartPasteApplication.swift`
   (composition root — wire the real rules in), `Tests/SmartPasteCoreTests/`.
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Scope
Pure Core logic, deterministic tests, each rule a visible refusal reason:
1. **Concealed/transient Active Item** → `.suspectedSecret`. The marker detection already lives in
   MacInterop (`PasteboardMarkers.swift`) and arrives as `ClipboardItem.isConcealed`; keep that boundary.
2. **Secure Target** (`AXSecureTextField` or `IsSecureEventInputEnabled()`, both already folded into
   `BoundTarget.isSecureField`) → `.secureField`.
3. **Suspected-secret rules over the Active Item text** (gitleaks-style prefix/format rules, no entropy):
   PEM private-key blocks, `AKIA…`, `ghp_`/`github_pat_`, `xox[baprs]-`, `sk_live_`, `sk-…`, `AIza…`,
   three-part base64url JWTs, connection strings with inline credentials. Each rule a named, individually
   tested value; the set is one `SuspectedSecretRules` (or better-named) type, linear-time matching (a review
   once caught a regex hang in Candidate derivation — prove no catastrophic backtracking, prefer non-regex
   scanning). Match → `.suspectedSecret`, no Jev call, no pasteboard write.
4. **Secrets in the Target Context**: the same rules run over the captured surrounding-text window before it is
   sent; a match **drops that window** (paste proceeds with label/placeholder only) and the outcome carries a
   visible note. This is not a refusal; propose at GATE A where it lives (the coordinator before it builds the
   `Decision`? a dedicated Core type the coordinator calls?) and what the visible note looks like — it may need a
   small port/outcome change; say so explicitly.
5. Move the composed `PreCheck` into Core (the interim shell type goes away); the shell only composes.
6. Indicator wording per the lifecycle decision: "No text field focused", "Secure field — not supported",
   "Suspected secret — blocked" (check `OutcomeMessage` — keep what already exists, add what is missing).

Out of scope: the history UI, the ChatGPT resolver, Candidate derivation, Jev semantics, any per-Target
multi-line rule.

## Steps
1. `docs/design/pre-checks.md` (≤ 70 lines): rule table (rule → detection → refusal/note → test), the
   type layout and file names, the GATE A decision for item 4 restated in three lines, and the live-run plan.
   **GATE A**: ask with the path and the item-4 proposal.
2. Implement TDD, small commits (`make check` green before each).
3. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files, and a one-line proof per rule
   (test names). The supervisor reads the Core diff before approving.
4. Live proof (gated, one `ask`, batched with the other workers' live runs — expect a wait): after
   `make install`, the supervisor puts a synthetic secret on the clipboard (`printf 'ghp_JEVPASTE0000000000000000000000000000' | pbcopy`)
   and Daniel presses ⌘⇧V in a Chrome `data:` textarea → indicator "Suspected secret — blocked", nothing
   inserted, clipboard intact. Then a plain synthetic item → ordinary ✓ (regression). Give the supervisor the
   exact instruction block and the `log show` command; record log lines (no payloads).
5. Push. Post a report comment on issue #20: what was built, rule table, test count, live evidence, commits,
   merge touchpoints (files the composition root changed), open questions. **GATE C**: ask with the comment
   URL, then end your turn. Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Descriptive names from the glossary. No new dependencies without `ask`. Commit small on `pre-checks`; push
  after each gate. Do not merge.
- Shared files with the parallel `chatgpt-resolver` worker (MacInterop): none expected. Do not touch
  `Sources/MacInterop/`; if a rule seems to need it, `ask`.

## Report format
`[prechecks] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
