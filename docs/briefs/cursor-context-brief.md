# Brief — Read nearby text around the text cursor, without an app list (issue #51)

You are a fresh Pi session (`anthropic/claude-opus-5-5:high`) in worktree
`~/.pi/worktrees/jevpaste/cursor-context`, branch `cursor-context` (forked from `main`). This is a **production
slice**: TDD, review chain, merged when done. Your supervisor's intercom id is in your launch prompt — use exactly
that id; ignore any other pi in the repo's cwd. Daniel (owner) speaks **only through the supervisor**. Another
worker may run the Narrowing spike in parallel; it touches only `spikes/` on another branch — no shared files.
The installed app is shared with Daniel's daily use — `make install` only when a gate reply says go.

Communication protocol:
- `intercom send <id>` one line after every numbered step: `[cursor-context] step N done — <fact>`.
- `intercom ask <id>` (blocking) at each **GATE** and before every live action; prefix with `[cursor-context]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print `~/.config/jevpaste/env`. Never log or print item text, surrounding
  text or window titles; refer only to `JEVPASTE-…` synthetic markers.

## Read first (in this order)
1. `gh issue view 51` — your ticket (the assignee is the claim; leave it).
2. The decision: `gh api repos/DanielMulec/jevpaste/issues/comments/5845599979 -q .body` — section "Also
   decided", bullet "No app names in behaviour" (Daniel: "it's supposed to be able to smart paste anything
   anywhere, thanks to Jev — we don't need to name any specific apps"). Bullet 9 of the inventory: the reading
   bounds (2000 characters, 600 elements, 10 sibling labels, 250 ms) **stay**.
3. `CONTEXT.md` (**Target Context**, **Pre-check** — the secret screening of surrounding text stays in Core),
   `gh issue view 1` **Notes** (hard rules: 400 lines/file incl. tests; no payloads in logs), `docs/quality-gate.md`,
   `docs/design/mac-interop.md`, `Makefile`.
4. The code you change: `Sources/MacInterop/SurroundingTextCollector.swift` (the `terminalBundleIdentifiers` list
   and its suffix branch), `TargetContextReader.swift`, `AccessibilityNode.swift` / `AXElementNode.swift` (no
   selected-range attribute exists yet), and their tests.

## Scope
1. **Delete the terminal bundle-id list.** No app, bundle id or app name may decide behaviour anywhere in the
   collector (grep the package for bundle ids afterwards; the pasteboard markers in `PasteboardMarkers.swift`
   are out of scope — Daniel kept them).
2. **One rule for every app:** when the focused field's **own text is longer than the 2000-character
   surrounding-text limit** (a terminal exposes its whole window that way; a long document or textarea too), the
   nearby text is a 2000-character window of that text **around the text cursor** (the focused element's
   selected-text range / insertion point via Accessibility). If the app reports no cursor, take the **last** 2000
   characters. Otherwise read the page as today. Propose at GATE A how the window sits around the cursor (e.g.
   mostly before it) and why.
3. Keep every existing bound and the time budget; a new AX read must respect the 250 ms budget and stay one call.

Out of scope: Narrowing, Jev wording, the Pre-check rules, the resolver/Wake Wait, any UI.

## Steps
1. **Gate A measurement:** which targets report a cursor through Accessibility on the focused element — Ghostty
   (Herdr), Terminal.app, TextEdit (long document), Chrome `<textarea>` with a long value and the caret in the
   middle, the ChatGPT composer. Worker shells have no Accessibility, so measuring needs the signed app: propose
   an off-by-default probe (like `--accept-signal-trigger`) or an instrumented build that logs only
   `cursorReported=<bool> ownTextLength=<n>` and marker booleans — never text. `ask` before any `make install`.
   Report the table in one `send`.
2. `docs/design/cursor-context.md`. **GATE A** (`ask`): the doc path, the Gate A table, the window placement, the
   seam change (new node attribute), and what the probe leaves behind in `main` (off by default, or removed).
3. Implement TDD, small commits (`make check` green before each). Fakes must model the documented AX contract
   (a missing cursor, an out-of-range cursor, a value shorter than the limit) — reviewers have twice found fakes
   that fire or answer more loosely than the real seam. Push after each gate.
4. **GATE B** (`ask`): the `make test` summary line, `wc -l` of every file you touched, a one-line proof per scope
   item (test names). The supervisor reads the MacInterop diff before approving.
5. Live proof (gated; ask once for `make install`). Automated, no Daniel: (a) a Herdr shell with ~300 lines of
   scrollback — `JEVPASTE-OLD-51` lines at the top, `JEVPASTE-NEAR-51` right above the prompt — fire SIGUSR1 at
   the prompt: the log shows NEAR contained, OLD not (booleans only), the paste lands unexecuted, then
   `herdr pane send-keys <pane> C-c`; (b) a Chrome `data:` page with a long `<textarea>`, the caret in the middle
   between two markers → the window holds the marker near the caret; (c) a short labelled Chrome field →
   unchanged page-walk behaviour (regression). Gate every synthetic trigger on a verified focused pane /
   frontmost app (Chrome DevTools MCP `hasFocus()` is not a key-window check). Every helper output that backs a
   claim goes into `docs/acceptance/run-<date>-cursor-context.log` at run time. If a step truly needs Daniel,
   batch it into **one** `ask` in plain words saying why each step exists.
6. Push. Report comment on issue #51: what was built, the Gate A table, test count, live evidence, commits, merge
   touchpoints, open questions. **GATE C**: `ask` with the comment URL, then end your turn. Do not merge, do not
   close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Glossary names. No new dependencies without `ask`. Bare `swift test` does not link — use `make test`.
- Reviewers read the committed log, not your session: every count backing a claim goes into the log.

## Report format
`[cursor-context] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
