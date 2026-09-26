# PROTOTYPE — menu-settings (issue #37), never merged

Throwaway UI prototype on branch `prototype/menu-settings`. Answers the three open questions of #37 for the
status-item menu with **History Search** and the **Settings** window. Own executable target
`MenuSettingsPrototype` (status-item image: SF Symbol `sparkle`), no Accessibility, no hotkey, no Jev, no
Keychain, no disk: every action changes in-memory state only, and the state is shown in every window.

## Launch

```
make prototype          # = swift run MenuSettingsPrototype
```

Runs next to the production JevPaste (different process, different status item). Quit from its own menu.
Variant switch: **Variant ▸** submenu at the bottom of the prototype's menu (Menu A/B · Rows 1/2/3 ·
Settings 1/2/3); every window shows a small label `Menu A · Rows 2 · Settings 1 · Active: "…"`.
Screenshot hooks (for the contact sheets only): `PROTO_OPEN=menu|settings PROTO_QUERY=<text>` env vars open the
menu or Settings after 1 s with a typed query, so a shell command can capture it.

## Question 1 — field inside a real `NSMenu`, or a menu-shaped panel?

- **Menu A — real `NSMenu`.** `statusItem.menu` is an `NSMenu`; item 0 is an `NSMenuItem` whose `view` holds an
  `NSSearchField`. On `menuWillOpen` / `menuDidOpen` the field is made first responder of the menu's window.
  `controlTextDidChange` rebuilds the result items (≤ 5 `NSMenuItem`s + "Full history…") between the field and
  Settings…/Quit while the menu stays open. ↑/↓/Enter/Esc are whatever AppKit's menu tracking does with them
  (observed, not patched, except one documented attempt via `control(_:textView:doCommandBy:)`).
- **Menu B — menu-shaped panel.** No `NSMenu`: a click on the status item opens a borderless, key-capable,
  non-activating `StatusItemPanel`-style panel under the item (`StatusItemPlacement`), with the menu material
  (`.menu`), menu corner radius, menu row height and highlight, the same three items. The field is first
  responder on open; ↑/↓ move a highlight through rows, Enter chooses, Esc and click-outside close. Everything
  is ours, so all behaviour is explicit code.

Both are built completely; the table is filled from what AppKit actually does on this Mac (macOS 26).

How observed: `PROTO_SELFTEST=1 PROTO_MENU=A|B make prototype` opens the menu and posts synthesised key events
(`NSApp.postEvent`, in-process, addressed to the menu's window) and logs every responder callback (`[proto] …`);
macOS 26.6.2. `CGEvent.postToPid` delivered nothing (no Accessibility for the terminal), so no event came from
outside the process. Pointer-driven checks (row click in A, the auto-hiding bar) cannot be synthesised: posted
mouse events and `CGWarpMouseCursorPosition` do not move NSMenu's highlight — those cells need Daniel's hand.

| Check | Menu A — `NSMenu` + field view | Menu B — menu-shaped panel |
|---|---|---|
| Typing focuses the field without a click | **Yes, observed**: the field view becomes first responder of the menu's `NSPopupMenuWindow` in `viewDidMoveToWindow` (`makeFirstResponder` → true); "e","x" reached it. The window is never key: **no caret, no focus ring** (screenshot) | **Yes, observed**: the non-activating panel becomes key without activating the app; caret + focus ring. Pitfall hit: re-adding the field to the view tree on each rebuild dropped its field editor after the 1st char — the field must stay mounted |
| ↑/↓ move through the result rows | **Yes, but by NSMenu, observed**: menu tracking eats ↑/↓ (the field never gets `moveUp:`/`moveDown:`), highlight walks the rows and skips the field. **After an arrow the field is dead**: "a" and ⌫ go to NSMenu's type-select (highlight jumped to "Full history…"), field text stayed "ex" until the menu reopened. Empty field: ↓ lands on "Settings…" | **Yes, observed**: field gets `moveDown:`/`moveUp:` via `control(_:textView:doCommandBy:)`, our highlight moves; typing after an arrow keeps editing ("ex"+"a" → "exa"), ⌫ works |
| Enter chooses the highlighted row | **Yes, observed, two paths**: no highlight → Enter reaches the field as `insertNewline:` (prototype code picks the first row + `cancelTracking()`); highlighted row → NSMenu handles Enter itself and fires that item's action. Both: Active Item set, menu closed | **Yes, observed**: `insertNewline:` → highlighted row, else the first row; Active Item set, panel closed |
| Esc closes the menu | **Yes, observed**: NSMenu consumes Esc and closes at once, even with text in the field (field never sees `cancelOperation:`) | **Yes, observed**: `cancelOperation:`; prototype: 1st Esc clears text, 2nd closes (one line to make it close at once) |
| Menu re-lays-out as rows appear/disappear | **Yes, observed**: inserting/removing `NSMenuItem`s while tracking resizes the window live: 188 pt → 332 pt (5 rows + Full history…) → 188 pt after ⌫⌫, top edge fixed | **Yes, observed** (our code): 182 → 325 → 182 pt, top edge fixed under the status item |
| Survives the auto-hiding menu bar | **Not observable synthetically.** Observed only: opened while the bar was hidden (full-screen space), the menu appears in place under the hidden bar. Pointer leaving the bar → Daniel | **Not observable synthetically.** Same observation. Risk to check by hand: the panel is our window, not menu tracking, so the bar may hide while it is open (status item gone above it) → Daniel |
| (extra) Row click sets the Active Item | **Not observable synthetically**: a posted click closed the menu without choosing (NSMenu hit-tests the real pointer). Enter on a highlighted row fires the same item action — observed. Placeholder after reopen = new Active Item's first line (screenshot) → click is Daniel's step | **Yes, observed**: posted click on row 3 → Active Item = row 3, panel closed; reopened placeholder = its first line |

## Question 2 — row look (applies to both menu variants)

- **Rows 1 — plain menu line.** One line per Clipboard Item, first line truncated at ~45 chars, the Active Item
  marked by the menu's own leading ✓ column (like a checked menu item). No detail. "Full history…" is a plain item
  after a separator. Transition: rows appear directly under the field, no header.
- **Rows 2 — two-line rows.** First line in regular weight, dim second line with shape facts
  ("4 lines · 12 min ago"). Active Item: accent dot at the leading edge. A small dim header "5 of 12 matches"
  above the rows, "Full history…" carries the total ("Full history… (40)"). Transition: header + rows slot in.
- **Rows 3 — tagged, content-first.** Leading kind symbol (envelope / link / phone / text / code), monospaced
  one-line preview with the match highlighted in bold, right-aligned age; the Active Item gets a trailing
  capsule tag "Active". "Full history…" is right-aligned link-style text on the last row with the count.

## Question 3 — Settings layout

All three hold the same content: Open at Login · Jev Provider (Vercel AI Gateway = default, Typesafe direct) ·
one API key per provider (secure field, Show, Test → canned ✓ after 0.8 s; "Test" on an empty key shows the
error text) · Full History (list, per-item delete, guarded Clear History). Each has a `open(to: .key(provider))`
entry so the refusal "No key for <provider> — open Settings" lands on the right field (key field focused).

- **Settings 1 — toolbar tabs** (standard `NSTabViewController` `.toolbar` style): General (Open at Login) /
  Jev Provider (radio picker + two key rows) / Full History. Show = eye button inside the key row; Test result
  inline to the right of the Test button ("✓ Works" / red error).
- **Settings 2 — sidebar** (System Settings shape, split view): sidebar General / Jev Provider / Full History;
  right pane is a grouped form. Show = "Show key" checkbox under the field; Test result as a status line under
  the field, full width, so long errors wrap.
- **Settings 3 — one scrolling page**, no tabs: sections General → Jev Provider (popup picker, only the chosen
  provider's key row expanded, the other collapsed) → Full History (inline list, fixed height). Show = eye toggle;
  Test result as a badge in the section header ("Vercel AI Gateway — ✓ tested").

## Synthetic dataset (~40 Clipboard Items, invented)

Emails (6, e.g. `mara.lindqvist@example.org`), a 4-line postal address ×3 (invented streets/towns), URLs (5,
example.com / example.org), phone numbers (4, `+49 30 5550 1234` style), a 30-line build log, paragraphs (4),
`Label: value` blocks (3, invoice/booking data), code snippets (4: Swift, shell, JSON, SQL), IBAN-shaped
test value (DE00 0000…), dates, tracking numbers, short words. Ages spread over 2 min … 9 days. Nothing from
this machine; no real names or addresses.

## Screenshot plan

Captured with `screencapture -x -R` / `-l <windowID>`, cropped tight, made into contact sheets (4 across, big
numbers) by `scripts/prototype-contact-sheet.py` into `docs/prototype/menu-settings/`:

- `sheet-menu.png` — Menu A and B, each: empty field (3 items) and typed query with rows (4 cells).
- `sheet-rows.png` — Rows 1/2/3, each with the query `ex` (5 rows + Full history…) in Menu B (3–6 cells).
- `sheet-settings.png` — Settings 1/2/3: Jev Provider view after a ✓ Test, and Full History view (6 cells).

Rework rounds go into `round2-…` sheets; old sheets are never renumbered.
