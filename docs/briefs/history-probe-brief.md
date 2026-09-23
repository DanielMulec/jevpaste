# Brief — Validate history selection and visible paste feedback (issue #9)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/history-probe`, branch `history-probe` (forked from `main`). This is a **prototype**
ticket: throwaway code on a throwaway branch that is **never merged** — it is kept as a primary source. Your
supervisor is the Pi session with intercom id **`01a0cff5`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id. Daniel (owner) speaks **only through the supervisor** — every live step where Daniel acts
is an `intercom ask`, and you wait. **Two parallel workers exist** (`chatgpt-resolver`, `pre-checks`); the
installed app is shared — `make install` only when a gate reply says go, and expect to wait your turn.

Communication protocol:
- `intercom send 01a0cff5` one line after every numbered step: `[history] step N done — <fact>`.
- `intercom ask 01a0cff5` (blocking) at each **GATE** and for every live action; prefix with `[history]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. The history database
  holds Daniel's real clipboard: showing it **in the app UI to Daniel** is fine; never print rows in logs,
  reports or intercom messages — refer only to `JEVPASTE-…` synthetic rows.

## Read first (in this order)
1. `gh issue view 9` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. `~/.agents/skills/prototype/SKILL.md` and its `UI.md` — this is a **UI** prototype ("what should the
   interaction look and feel like"): several radically different variants, switchable at runtime, Daniel reacts
   live. Obey "Rules that apply to both"; the variant switch here is a status-item menu item, not a URL param.
3. The decisions you are validating: `gh issue view 1` **Notes** (selecting an older item *inside the app*
   makes it active until another copy/selection; switching apps does not clear it; failures need a visible
   indicator, never silent), `gh api repos/DanielMulec/jevpaste/issues/comments/5767988662 -q .body`
   (lifecycle: outcome wording, ⌘⇧V is the retry), `gh issue view 6 --comments` (history identity, per-item
   delete, clear-all, 500 default), `gh issue view 26 --comments` (chooser: key-capable non-activating panel,
   focus return to the Bound Target's app — reuse its parts).
4. Code you build on: `Sources/JevPasteApp/Chooser/*` (`ChooserPanel`, `StatusItemPanel`, `FirstClickView`,
   `TargetAppFocusReturn`), `Sources/JevPasteApp/StatusItemPanelParts.swift` (keep its explicit `@MainActor`
   on `FirstClickView`), `Sources/JevPasteApp/History/*`, `Sources/JevPasteApp/Indicator/*`,
   `Sources/SmartPasteCore/Capture/CopyCapture.swift` (`activeItem` — there is **no selection API yet**),
   `Sources/SmartPasteCore/Seams/HistoryRepository.swift`, `Sources/JevPasteApp/SmartPasteApplication.swift`.
5. `CONTEXT.md`, `docs/design/candidate-chooser.md`, `docs/design/capture-and-history.md`, `docs/signing.md`,
   `Makefile`.

## The question (from the ticket)
What **minimal** in-app interaction makes (a) which item is active and (b) what happened on paste
unambiguous? Build 2–3 genuinely different variants of a history surface (e.g. a status-item **menu** listing
recent items; a **panel** under the status item like the chooser with ↑/↓/Enter and per-item delete; a
**search-first** panel) and, in each, show the active item unmistakably. Daniel drives the same script through
each variant and reacts; the supervisor records his reactions. Findings you must produce:
1. Which variant (or mix) Daniel wants for the production history UI, and why, in his words.
2. Does selecting an older item, switching to a target app and pressing ⌘⇧V paste **that** item? Does a fresh
   ⌘C afterwards replace it? Does switching apps leave the selection alone? (Lifecycle facts, observed.)
3. Is failure feedback visible and understood — a refusal (non-editable target) and a failed attempt — with the
   selected item still active afterwards?
4. Focus: after choosing in the history surface, does focus return to the target so ⌘⇧V lands there?
5. **What the production UI needs from Core**: `CopyCapture` has no "make this older item active" operation —
   record the seam you had to add (probe-only) as the recommendation for
   [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27).

## Prototype rules (this branch only)
- Throwaway: no tests required, no polish; `git commit --no-verify` is allowed. Keep files ≤ 400 lines anyway.
  Mark every new file `// PROTOTYPE — history-probe, never merged` at the top. You **may** add a probe-only
  selection method to `CopyCapture` on this branch; say so in the report.
- Reuse the real adapters and the real SQLite history (Daniel sees his real items in the UI; synthetic
  `JEVPASTE-HIST-…` rows are added for the script via `pbcopy`, which the running app captures as copies).
- Surface the state: the indicator (or a small probe label) must show the active item's first line after every
  selection/copy so Daniel can see what changed.
- Build and install **signed** (`make install`) so the Accessibility grant holds.

## Steps
1. Plan one page in the worktree (`PROBE-PLAN.md`): the variants (one paragraph each, what makes them
   different), the shared run script for Daniel in plain words (what to click, what to look at, and *why* each
   step exists), and the findings template for items 1–5. **GATE A**: ask with the variant one-liners and the
   script outline.
2. Implement the variants behind a status-item menu switch. `make app`. **GATE B**: ask for install permission
   (the installed app is shared; you may be queued behind another worker's live run).
3. Live runs, one variant per `ask`: give the supervisor the exact instruction block for Daniel and what to
   report back. Record reactions verbatim as relayed. Then the lifecycle/failure/focus checks (items 2–4) on
   Daniel's preferred variant.
4. **GATE C**: ask with the filled findings (1–5) and your recommendation for the production history UI in
   ≤ 8 lines (surface, selection mechanics, active-item indication, delete/clear-all placement, Core seam).
5. After the supervisor's go: reinstall the production build — `ask` first; the supervisor will say from where.
6. Commit the probe code and `PROBE-PLAN.md` (with findings) on `history-probe` (`--no-verify` ok), push the
   branch. Post a report comment on issue #9: findings, recommendation, branch link. **GATE D**: ask with the
   comment URL, then end your turn. Do **not** merge, do **not** close the issue.

## Report format
`[history] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
