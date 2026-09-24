# Brief — Implement the history UI (issue #27)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/history-ui`, branch `history-ui` (forked from `main` @ 87a32b8 or later). This is a
**production slice**: TDD, review chain, merged when done. Your supervisor is the Pi session with intercom id
**`01a0d1b6`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly that id; ignore any other
pi in that cwd. Daniel (owner) speaks **only through the supervisor** — every live step where Daniel acts is an
`intercom ask`, and you wait. The installed app is shared: `make install` only when a gate reply says go.

Communication protocol:
- `intercom send 01a0d1b6` one line after every numbered step: `[history-ui] step N done — <fact>`.
- `intercom ask 01a0d1b6` (blocking) at each **GATE** and for every live action; prefix with `[history-ui]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. The history database holds
  Daniel's real clipboard: showing it **in the app UI to Daniel** is fine; never print rows in logs, reports or
  intercom messages — refer only to `JEVPASTE-…` synthetic rows.

## Read first (in this order)
1. `gh issue view 27` — your ticket (the supervisor assigns it to Daniel; that is the claim, leave it).
2. The decision you implement: the resolution and the prototype report of
   [Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9)
   (`gh issue view 9 --comments`, last two comments). Its asset is branch `history-probe` @ 30f0ed9 — read
   `PROBE-PLAN.md` and `Sources/JevPasteApp/History/*` **there** (`git show history-probe:<path>`); it is a
   primary source, never merged, so port ideas, not files.
3. `gh issue view 1` **Notes** (hard rules: 400 lines/file incl. tests; no payloads in diagnostic logs; refer
   to issues by title), `gh issue view 16 --comments` (slice plan + acceptance rules), `gh issue view 6 --comments`
   (history identity, per-item delete, clear-all, 500 default), `CONTEXT.md`, `docs/quality-gate.md`,
   `docs/design/candidate-chooser.md`, `docs/design/capture-and-history.md`, `docs/design/app-shell.md`, `Makefile`.
4. Code you build on: `Sources/SmartPasteCore/Capture/CopyCapture.swift` (`activeItem`; **no selection API
   yet**), `Sources/SmartPasteCore/Seams/HistoryRepository.swift`, `Sources/JevPasteApp/Chooser/*`
   (`ChooserPanel`, `TargetAppFocusReturn`), `Sources/JevPasteApp/StatusItemPanelParts.swift` (keep its explicit
   `@MainActor` on `FirstClickView`; if the link fails with an undefined-symbol mangling mismatch after adding
   files, `swift package clean`), `Sources/JevPasteApp/History/*`, `Sources/JevPasteApp/Indicator/*`
   (`IndicatorNoticeSurface`), `Sources/JevPasteApp/SmartPasteApplication.swift` (composition root).
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Scope
The production history surface, as decided on the prototype ticket:
1. **Core seam** (TDD first): `CopyCapture.select(_:)` — Active = item, no history write, no reorder — and an
   Active-Item-change observation port. Tests: a later copy replaces a selection; a selection during a Paste
   Attempt leaves the pinned item alone; deleting the Active Item keeps it Active in memory.
2. **Panel**: Spotlight-style, key-capable, non-activating panel under the status item, reusing the chooser's
   parts. Search field on top (filters as you type), 8–10 rows, pinned **Active** row at the top (symbol + 2–3
   preview lines). Opens from the status-item menu (keep the menu short); an optional global hotkey only if it
   costs nothing — propose at GATE A, default is no hotkey.
3. **Selection**: ↑/↓ + Enter, or click → item becomes Active, panel closes, focus returns to the target app
   via `TargetAppFocusReturn`. Esc / click-away closes without change. After a selection a brief
   "Active: <first line>" note via `IndicatorNoticeSurface` (never covering a paste outcome).
4. **Delete / clear-all**: ✕ on hover per row, ⌫ (and ⌘⌫) deletes the highlighted row; clear-all is a footer
   button behind a confirmation. Deleting the Active Item keeps it Active in memory (Core rule above).
5. **Rejev-paste live proof**: Daniel selects an older `JEVPASTE-…` item, switches to a target app, presses
   ⌘⇧V, and that item is what pastes. Plus the checks the prototype deferred: a fresh ⌘C replaces the selection;
   a refusal on a non-editable target leaves the selection Active; focus return — typing lands in the target
   after choosing.

**UI-quality bar (Daniel, verbatim): "make it look like something Apple would be proud shipping."** He handed
you the visual design. Requirements observed live: the Active Item is clear at a glance, selection feedback is
obvious, delete and clear-all are easy to find. Native materials, system fonts, SF Symbols, sensible spacing,
dark and light appearance, no custom chrome. **Propose the visual design at GATE A with a screenshot** (a
static mock rendered by the real panel code is fine — `make app`, run the unsigned build, screenshot the panel
with `screencapture`; do not `make install` for this).

Out of scope: Jev semantics, the skip-Jev rules (a separate ticket is being decided in parallel — do not touch
`PasteAttemptCoordinator+Decision.swift` or Candidate derivation), the ChatGPT resolver, pre-checks.

## Steps
1. `docs/design/history-ui.md` (≤ 80 lines): the Core seam (types, port, tests), panel anatomy and states,
   key map, file layout with names, the live-run script for Daniel in plain words (what to click, what to look
   at, *why* each step exists — one pure value per line in every synthetic row, marker on its own line), and
   the screenshot path. **GATE A**: ask with the doc path, the screenshot path, and the hotkey proposal.
2. Implement TDD, small commits (`make check` green before each). Core first, then the panel.
3. **GATE B**: ask with the `make test` summary line, `wc -l` of your files, and a one-line proof per
   scope item (test names, or "live" where only live proves it). The supervisor reads the Core and the panel
   diffs before approving.
4. Live proof (gated, one `ask` for install, then one `ask` per step block): synthetic rows via `pbcopy` (the
   running app captures them); Daniel drives; record his words as relayed and the log lines (no payloads).
5. Push. Post a report comment on issue #27: what was built, seam summary, test count, live evidence,
   commits, merge touchpoints (composition-root and shared-parts changes), open questions. **GATE C**: ask
   with the comment URL, then end your turn. Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Descriptive names from the glossary. No new dependencies without `ask`. Commit small on `history-ui`; push
  after each gate. Do not merge.
- Shared files: a parallel worker may soon touch `Sources/SmartPasteCore/PasteAttempt/*` and
  `Sources/JevPasteApp/Indicator/OutcomeMessage.swift`. Do not edit those; if you need to, `ask`.

## Report format
`[history-ui] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
