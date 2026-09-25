# Brief — Offer Enter to paste everything after No Suitable Match (issue #42)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/enter-after-no-match`, branch `enter-after-no-match` (forked from `main`). This is a
**production slice**: TDD, review chain, merged when done. Your supervisor is the Pi session with intercom id
**`01a0d9a8`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly that id; ignore any other
pi in that cwd. Daniel (owner) speaks **only through the supervisor** — every live step where Daniel acts is an
`intercom ask`, and you wait. **A parallel worker exists** (`free-text-target`, ticket #41); the installed app
is shared — `make install` only when a gate reply says go. See "Shared files" below.

Communication protocol:
- `intercom send 01a0d9a8` one line after every numbered step: `[enter] step N done — <fact>`.
- `intercom ask 01a0d9a8` (blocking) at each **GATE** and for every live action; prefix with `[enter]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. Never log or print item
  text; refer only to `JEVPASTE-…` synthetic payloads.

## Read first (in this order)
1. `gh issue view 42` — your ticket (assigned to Daniel; that is the claim, leave it).
2. The decision, verbatim: `gh api repos/DanielMulec/jevpaste/issues/comments/5821465655 -q .body`
   (resolution of [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35)).
   The map rule stands: **no automatic** unmodified-source fallback — Enter is a deliberate second act.
3. `CONTEXT.md` (**Direct Paste** — three doorways, **No Suitable Match**, **Paste Attempt** are the contract),
   `gh issue view 1` **Notes** (hard rules: 400 lines/file incl. tests; no payloads in logs; refer to issues by
   title), `docs/quality-gate.md`, `docs/design/direct-paste.md`, `docs/design/paste-attempt-state-machine.md`,
   `docs/design/candidate-chooser.md` (if present — the chooser is the existing key-capable non-activating
   panel), `Makefile`.
4. Code you will touch:
   - `Sources/SmartPasteCore/PasteAttempt/PasteAttemptCoordinator+Decision.swift` `decided(_:)` — the
     `finish(.noSuitableMatch)` line becomes "offer everything": a new phase (`PasteAttemptPhase.swift`),
     off the clock like the chooser, resolved by a reply closure through a port. **Touch nothing else in
     `decided(_:)`** — the parallel worker adds a guard at its top.
   - `Sources/SmartPasteCore/Seams/PasteOutcomePresenter.swift` or `CandidateChooser.swift` — where the offer
     lives is your GATE A proposal: a new presenter method (`showNoSuitableMatchOffer(onAccept:onDismiss:)`) or
     a new small seam. Prefer the smallest port change that keeps the Core single-writer and testable with the
     existing fakes.
   - `Sources/SmartPasteCore/DirectPaste/DirectPasteRule.swift` — reuse its text transformation (outer line
     breaks stripped) for the whole Active Item; do not re-implement.
   - `PasteAttemptCoordinator+Delivery.swift` `deliver(_:)` — reused as is (Bound Target re-verified there).
   - `Sources/JevPasteApp/Indicator/IndicatorPresenter.swift`, `OutcomeMessage.swift`, `IndicatorPanel.swift`,
     `IndicatorSurface.swift` — the offer text **"No suitable match — press Enter to paste everything"** and
     the one-key capability. The indicator is non-activating and not key-capable today; the chooser
     (`Sources/JevPasteApp/Chooser/ChooserPanel.swift`, `PanelCandidateChooser.swift`, `TargetAppFocusReturn.swift`)
     already is key-capable, returns focus to the Bound Target's app before replying once, and cancels on
     Esc/click-away. **Reuse that mechanism** (extract the shared part into a named type both panels use);
     do not duplicate it — the reviewer runs a semantic-duplication check.
   - `Sources/SmartPasteCore/Values/SmartPastePath.swift` — the log must read
     `outcome inserted via=directPaste reason=enterAfterNoMatch`; propose at GATE A whether that is a new path
     case or a note (`PasteAttemptNote`). The parallel worker adds `.freeTextTarget` to the same enum — additive.
   - `Tests/SmartPasteCoreTests/`, `Tests/JevPasteAppTests/` as they exist.
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Tools for the live proof: the Chrome DevTools MCP server `chrome-devtools` (lazy: `mcp({connect:"chrome-devtools"})`
   first; `new_page`, `click`, `fill`, `evaluate_script`, `close_page` — re-list and verify the title before
   closing anything; it drives Daniel's real Chrome). Herdr CLI for terminal steps (`herdr pane get <id>`
   focused=true + frontmost-app check before every synthetic step, `send-keys`, `read --source visible`). The
   installed app started with `--accept-signal-trigger` accepts `kill -USR1 <pid>` as ⌘⇧V
   (`Sources/JevPasteApp/Launch/AcceptanceTrigger.swift`). Enter/Esc on the offer are keystrokes to **our**
   panel — you can post them from Herdr only if our panel is key; otherwise Daniel presses them.
7. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Scope
1. **Offer phase** in Core: after Jev's `none_of_these` / below-threshold gate the attempt does not end; it
   shows the offer and waits, off the 5 s clock. Enter → `deliver(wholeItemText)` (Direct Paste text, Bound
   Target re-verified by `deliver`, pre-checks already passed at attempt start — do not re-run them, say so in
   the doc). Esc, click-away, a new ⌘⇧V, or the offer timeout → attempt ends as `noSuitableMatch` with nothing
   inserted. Tests through the fakes: Enter delivers the whole item; Esc/timeout deliver nothing; a late Enter
   after the attempt ended is ignored (attempt-number guard); the target-changed case fails visibly.
2. **Offer timeout**: propose a duration at GATE A (the chooser has none; an indicator note should not sit
   forever — Daniel's menu bar auto-hides). Named constant, tested with the fake clock.
3. **Shell**: the offer is visible on the indicator with the exact wording above; Enter is accepted when the
   offer is showing; focus returns to the Bound Target's app before delivery (as the chooser does). Decide
   at GATE A: does the offer *take* key focus like the chooser (then Enter in the target app is not swallowed
   by the target — good) or does it listen globally (no)? Recommended: the chooser mechanism.
4. **Log**: `outcome inserted via=directPaste reason=enterAfterNoMatch`; a dismissed offer logs the existing
   `noSuitableMatch` outcome plus `offer=dismissed|timedOut`. Enums only.
5. **Docs**: `docs/design/direct-paste.md` (second doorway: after No Suitable Match), state-machine doc (new
   phase), chooser/indicator doc for the shared key-capable part. `CONTEXT.md` only if the implementation
   proves a wording wrong (say so).

Out of scope: the Free-text Target question (#41), the cold-AX wake (#36), any automatic fallback, changes
to Jev requests, the history panel look (#37).

## Shared files with the parallel worker `free-text-target` (#41)
- `PasteAttemptCoordinator+Decision.swift` `decided(_:)`: you own the `finish(.noSuitableMatch)` line and what
  replaces it; #41 owns the first guard of the function. Touch nothing else there.
- `PasteAttemptPhase.swift`: you add the phase; #41 may change `RunningAttempt.path` only.
- `SmartPastePath.swift`: additive on both sides.
- `IndicatorPresenter.swift`: #41 changes **only** `outcomeLogLine`; you own the rest. `OutcomeMessage.swift`,
  `IndicatorPanel.swift`, the Chooser files: yours alone.
- `Decision.swift`, `BoundTarget.swift`, `JevGateway/`, `MacInterop/`: do not touch.
- Tests: add **new** test files (`NoSuitableMatchOffer…Tests.swift`) rather than editing `PasteAttempt*Tests`
  heavily. The supervisor merges whichever branch is ready first and asks the other to rebase; expect one rebase.

## Steps
1. `docs/design/no-suitable-match-offer.md` (≤ 70 lines): the phase and its transitions (3 lines of the state
   machine), the port shape, the key-capability reuse plan (which type is extracted from the chooser, its name),
   the timeout, the log shape, the test list, and the **live-run plan** in plain words (what is opened, what is
   pressed, what is looked at, *why* each step exists — e.g. "Esc first, to prove nothing is inserted without
   Enter"). **GATE A**: ask with the doc path and the four proposals (port, key reuse, timeout, log shape).
2. Implement TDD, small commits (`make check` green before each). Push after each gate.
3. **GATE B**: ask with the `make test` summary line, `wc -l` of your files, and a one-line proof per scope
   item (test names). The supervisor reads the Core diff before approving.
4. Live proof (gated; ask once for `make install`, then one `ask` for the block — expect to wait for the other
   worker's turn). Payload: a two-line item of values that no labelled field wants, e.g.
   `JEVPASTE-ENTER-ONE` / `JEVPASTE-ENTER-TWO` (pure values per line) into a Chrome `data:` page with a
   labelled *Phone* input (Jev should say none of these). Steps, each with its why: (a) ⌘⇧V → offer text shown
   → **Esc** → nothing inserted, log `noSuitableMatch offer=dismissed`; (b) ⌘⇧V → offer → wait past the
   timeout → nothing inserted, `offer=timedOut`; (c) ⌘⇧V → offer → **Enter** → both lines landed in the
   field (flattened by the input, as the multi-line probe showed), `via=directPaste reason=enterAfterNoMatch`,
   clipboard restored; (d) regression: a labelled *Email* field with a matching payload → ordinary excerpt ✓.
   Chrome steps automated where the key gate allows; Daniel presses Esc/Enter if our panel cannot be driven.
   Record log lines (`log show … --info`, no payloads).
5. Push. Post a report comment on issue #42: what was built, the phase, test count, live evidence, commits,
   merge touchpoints (shared files changed, the extracted key-capable type), open questions. **GATE C**: ask
   with the comment URL, then end your turn. Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Descriptive names from the glossary. No new dependencies without `ask`. Commit small on
  `enter-after-no-match`. Bare `swift test` does not link — use `make test`. Do not merge.
- The `FirstClickView` in `StatusItemPanelParts.swift` keeps its explicit `@MainActor` (documented linker case).

## Report format
`[enter] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
