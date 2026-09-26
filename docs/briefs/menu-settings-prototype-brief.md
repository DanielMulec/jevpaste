# Brief — Prototype the status-item menu with History Search and the Settings window (issue #37)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium` — Daniel chose medium for this prototype,
2026-09-26) in worktree `~/.pi/worktrees/jevpaste/prototype-menu-settings`, branch `prototype/menu-settings`
(forked from `main`). This is a **prototype** ticket: throwaway code on a throwaway branch that is **never
merged** — it is kept as a primary source. Your supervisor is the Pi session with intercom id
**`01a0df77-ec24-77bc-8ce1-3ce59910d298`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly
that id, even if another id appears anywhere else. Daniel (owner) speaks **only through the supervisor**, from his
phone: he looks at screenshots and picks by number, and tries the keyboard behaviour on his Mac when asked.

Communication protocol:
- `intercom send <supervisor>` one line after every numbered step: `[proto] step N done — <fact>`.
- `intercom ask <supervisor>` (blocking) at each **GATE**; prefix with `[proto]`. Anything unexpected → `ask`.
- Answer asks you receive with `intercom reply`; if that fails ("no pending ask"), use `intercom send`.
- Never block in a long sleep. Never print `~/.config/jevpaste/env`. **Never read, show or screenshot Daniel's real
  clipboard history** (`~/Library/Application Support/jevpaste/history.sqlite`): the repo is public and screenshots
  go onto the branch — the prototype uses a **synthetic in-memory dataset only** (see rules).

## Read first (in this order)
1. `gh issue view 37` — your ticket (assigned to Daniel = claimed; leave it). The three open questions are there.
2. `~/.agents/skills/prototype/SKILL.md` and its `UI.md` — a **UI** prototype: several *radically different*
   variants, switchable at runtime, Daniel reacts. Obey "Rules that apply to both". The variant switch here is a
   "Variant ▸" submenu at the bottom of the prototype's own status-item menu (plus a label in every window).
3. The decision you are giving a shape to — read it whole:
   `gh api repos/DanielMulec/jevpaste/issues/comments/5849649811 -q .body` (decisions 2, 4, 5, 6 matter here).
4. `CONTEXT.md` — use its terms: **History Search**, **Full History**, **Jev Provider**, **Active Item**,
   **Clipboard Item**. Wrong terms in UI text will be sent back.
5. Code you take the look from (do not modify `main`'s files; copy what you need into prototype files):
   `Sources/JevPasteApp/MenuBarDelegate.swift` (today's menu), `Sources/JevPasteApp/HistoryPanel/*` (the panel
   Daniel rejected — do **not** reuse its look, only learn what a row of a Clipboard Item holds),
   `Sources/JevPasteApp/Chooser/*` and `StatusItemPanelParts.swift` (key-capable non-activating panel under the
   status item — the "menu-shaped panel" variant can build on this; keep the explicit `@MainActor` on
   `FirstClickView`), `Sources/JevPasteApp/StatusItemPlacement.swift`.

## The decided design (verbatim from the decision; do not re-decide it)
- **Status-item menu:** the Clipboard History panel goes away. Menu = **History Search** field · **Settings…** ·
  **Quit**. Typing filters Clipboard History and lists up to **5** matching rows under the field, then
  **"Full history…"**, then Settings… and Quit; empty field → three items again. **Clicking a row makes it the
  Active Item** (nothing pasted). The search field's **placeholder shows the Active Item's first line**.
  Per-item delete and Clear History live only in the **Full History** tab of Settings.
- **Settings window** (standard macOS Settings window, "Settings…" in the menu). Contents: **Open at Login**,
  **Jev Provider** picker (Vercel AI Gateway — the default — or Typesafe direct), one **API key** field per
  provider (secure field with Show toggle, "Test" button = one cheap Jev call → ✓ or the error), and a
  **Full History** tab (list, per-item delete, guarded Clear History). Nothing else.
- No key for the chosen provider → the ⌘⇧V refusal reads "No key for <provider> — open Settings" (clickable).
  You do not build that; but the Settings window must be a place that message can open *to the right spot*.

## The three questions the prototype settles (from the ticket)
1. **Field inside an open `NSMenu`, or a menu-shaped panel?** Build **both** and report facts, not preference:
   with a text field as an `NSMenuItem.view` inside a real `NSMenu` — does typing focus it without a click, do ↑/↓
   move through the result rows, does Enter choose the highlighted row, does Esc close the menu, does the menu
   re-layout as rows appear/disappear, does it survive the menu-bar auto-hide Daniel uses? Then the same six checks
   for a menu-shaped panel (a borderless key-capable panel under the status item that *looks* like a menu). Write
   the answers as a 2-column table before Daniel sees anything. If the `NSMenu` variant fails a check, say which and
   why (what AppKit does), and still ship it so Daniel can feel the difference.
2. **Row look:** 2–3 structurally different takes — e.g. one plain line per item; two lines (first line + dim
   second line / age); leading mark for the Active Item vs. trailing "Active" tag — and the "Full history…" item
   under the rows, and the transition three-items ↔ rows.
3. **Settings layout:** 2–3 takes — e.g. toolbar tabs (General / Jev Provider / Full History) vs. one scrolling
   page vs. sidebar; where the Test result (✓ / error text) shows; how the key field's Show toggle looks.

## Prototype rules (this branch only)
- Throwaway: no tests, no `make check`, `git commit --no-verify` is allowed. Keep files ≤ 400 lines anyway.
  Mark every new file `// PROTOTYPE — menu-settings, never merged` at the top.
- **Do not install over the production app** and do not touch `~/Applications/JevPaste.app`. Build the prototype
  as its **own** app: a separate executable target (e.g. `MenuSettingsPrototype`) launched with `swift run`, or
  a throwaway ad-hoc bundle under `/tmp/` with a different bundle id and a visibly different status-item image
  (e.g. SF Symbol `sparkle`), so two status items sit side by side and nobody confuses them. It needs no
  Accessibility, no hotkey, no Jev, no Keychain: **read-only stubs** everywhere — "Test" shows a canned ✓ after
  0.8 s, provider/key/login toggles change in-memory state, a row click sets the in-memory Active Item and the
  placeholder follows, so Daniel can see the state change (surface the state).
- **Synthetic data only:** ~40 in-memory Clipboard Items with realistic *shapes* (emails, a postal address of
  4 lines, a URL, a phone number, a 30-line log, a paragraph, a `Label: value` block, a short code snippet, some
  duplicates of shape) under invented names — nothing from Daniel's machine, no real names or addresses.
- One command starts it (`make prototype` or a documented `swift run …` line in `PROTOTYPE-PLAN.md`).

## Screenshots for Daniel
- Daniel picks from **contact sheets**: PNGs at 4 across, made with PIL (`python3 -m pip install --user pillow` if
  missing), each cell numbered `1, 2, 3…` in a big label, one sheet per question (menu variants; row looks;
  Settings layouts). Capture with `screencapture -x -R <x,y,w,h>` (or `-l <windowID>` for windows) while the
  prototype shows the state; open the status-item menu programmatically (`statusItem.button?.performClick(nil)`
  after a short delay) so a shell command can capture it. Retina 2x is fine; crop tight.
- Sheets go to `docs/prototype/menu-settings/` on the branch (synthetic data → committable) **and** you tell the
  supervisor the absolute paths; the supervisor sends them to Daniel's phone.
- Daniel also needs to **feel** question 1 himself. Give the supervisor a plain-words script (what to click, what
  to type, what to look at, and *why* each step exists) for both variants, ≤ 8 steps each; the supervisor opens
  the prototype app for him (say the exact launch command).

## Steps
1. Plan one page in the worktree (`PROTOTYPE-PLAN.md`): the launch command, the variants for each of the three
   questions (one paragraph each, what makes them structurally different), the synthetic dataset outline, the
   screenshot plan, and the question-1 fact table with empty cells. **GATE A**: ask with the plan's one-liners.
2. Build. First the question-1 pair (menu vs panel) and fill the fact table; `[proto] step 2 done — <table>`.
   Then rows, then Settings. Commit as you go (`--no-verify`), push the branch.
3. **GATE B**: ask with the three contact-sheet paths, the fact table, and the two feel-scripts. Wait. The
   supervisor relays Daniel's picks ("menu: 2; rows: 1 with the tag from 3; settings: 2") and remarks; rework
   into a new numbered sheet (never renumber old ones — `round2-…`), ask again. Loop until the supervisor says
   the look and behaviour are settled.
4. Write the settled design into `PROTOTYPE-PLAN.md` ("Settled" section: menu mechanism + why, row look,
   Settings layout, Test-result placement, and every AppKit fact the build must know — e.g. how the field gets
   focus inside the menu, what events the menu swallows). Commit, push.
5. Post a report comment on issue #37 (write it to a file, `gh issue comment 37 --body-file …`): the settled
   design, the fact table, the chosen sheet images (link the files on the branch), the branch link, and what the
   build ticket needs from Core (e.g. a history search seam, an Active-Item selection port). **GATE C**: ask with
   the comment URL, then end your turn. Do **not** merge, do **not** close the issue.

## Report format
`[proto] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
Screenshots and UI text: CONTEXT.md terms, no real data, no `/Users/<name>` paths in committed files.
