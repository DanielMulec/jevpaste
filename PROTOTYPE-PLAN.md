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

## Feel scripts for Daniel (question 1)

Launch (the supervisor): `cd ~/.pi/worktrees/jevpaste/prototype-menu-settings && make prototype` — first build
≈ 1 min; a ✦ (sparkle) appears next to JevPaste's own icon. Everything is fake: nothing is pasted or stored.

**Menu A — real NSMenu** (the default at launch)
1. Click ✦. Look at the field: it shows the Active Item's first line in grey. *Why: the placeholder is the Active Item.*
2. Without clicking the field, type `ex`. Rows appear, the menu grows. Is there a blinking caret? *Why: focus without a click — in A text arrives, but no caret shows.*
3. Press ↓ twice. The highlight walks down the rows. *Why: arrows in a real menu.*
4. Now type `a`, then ⌫. Did the field text change, or did the highlight jump? *Why: the prototype found the field goes deaf after an arrow key.*
5. Press Enter. The menu closes. Click ✦ again: the grey placeholder now shows the item you chose. *Why: Enter makes it the Active Item.*
6. Type `ma`, then **click** the second row with the mouse. Reopen: did the placeholder change? *Why: a mouse click could not be tested without your hand.*
7. Type `ex`, press Esc once. *Why: in A one Esc closes everything, even with text typed.*
8. With a full-screen app in front (menu bar hidden), move the pointer to the top, click ✦, type `ex`, move the pointer down over the rows. Does the menu bar stay visible? Does the menu stay? *Why: your auto-hiding menu bar can't be simulated.*

**Menu B — menu-shaped panel** (✦ → Variant → "Menu B — menu-shaped panel", then click ✦)
1. Click ✦. Caret blinking in the field, grey placeholder = Active Item. *Why: B can show focus; A can't.*
2. Type `ex`. Rows appear, the panel grows. *Why: same as A, compare the feel.*
3. Press ↓ twice, then type `a`, then ⌫. The field keeps editing. *Why: the difference from A step 4.*
4. Press ↓ then Enter. It closes; reopen: placeholder = chosen item. *Why: Enter chooses.*
5. Type `ma`, click the second row. *Why: click path.*
6. Type `ex`, press Esc (clears the text), Esc again (closes). Reopen and click somewhere else on the screen: it closes. *Why: is two-step Esc right, or should one Esc close?*
7. Same as A step 8 with the full-screen app. Does the menu bar hide while the panel stays open, and does ✦ still close it? *Why: the panel is not a real menu, so macOS may hide the bar under it.*
8. Compare the look of A and B side by side (colour, corners, row height, highlight). *Why: B is drawn by us and can only imitate a menu.*

## Settled (Daniel, 2026-09-26, rounds 1–3)

Sheets: `docs/prototype/menu-settings/round3-menu.png` (menu), `round2-settings.png` (Settings); round-1 sheets
keep the rejected variants. Prototype defaults are now the settled look: `make prototype` opens Menu B · Rows 2
· "Full history…" take 2 · Settings 1.

### Menu mechanism: Menu B — a menu-shaped panel, not a real `NSMenu`
Why (observed, fact table above): inside a real `NSMenu` the field is never in a key window (no caret, no focus
ring), menu tracking takes ↑/↓, and after one arrow key every later letter and ⌫ goes to NSMenu's type-select
instead of the field until the menu reopens. The panel owns all keys and shows focus.

### Row look: Rows 2
- Under the field, a separator, then a dim header "N of M matches" (11 pt semibold, secondary colour).
- Up to 5 rows, 38 pt each: first line of the Clipboard Item (menu font, truncated tail) over a dim second line
  "N lines · age" or "N chars · age" (11 pt). The Active Item is marked by an accent dot in the leading slot
  (14 pt wide); other rows leave the slot empty so titles align.
- No match → a dim "No matching Clipboard Items" line.
- Separator, then **one block: "Full history…" · "Settings…" · "Quit"**, all the same menu item style.
  "Full history…" carries the Clipboard History count right-aligned in parentheses, "(40)", secondary colour; its
  right inset equals the titles' left inset (symmetric; 25 pt inside the row).
- Empty field → field, separator, Settings… and Quit (three items); the block shrinks back. The panel keeps its top
  edge under the status item and grows/shrinks downward.
- Placeholder = the Active Item's first line; no Active Item → "Search Clipboard History".

### Settings: Settings 1 — standard toolbar tabs (`NSTabViewController`, `.toolbar`)
- **General**: Open at Login (switch). Nothing else.
- **Jev Provider**: radio picker "Vercel AI Gateway (default)" / "Typesafe direct" with one line explaining no
  silent switch; then one key row per provider: secure field · eye button (Show; swaps to a plain field holding the
  same text) · "Test".
- **Test result: inline to the right of the Test button**, wrapping to two lines: "✓ Works — Jev answered through
  <provider>." green, or "✕ <error>" red; "Testing…" while running. Editing the key clears the result.
- **Full History**: inset table, two lines per item (first line / "N lines · age"), "Active" capsule on the Active
  Item, ✕ delete per row, footer "N Clipboard Items" + "Clear History…" → sheet alert with a destructive "Clear
  History" and Cancel.
- Window height follows the selected tab (top edge fixed); title = tab name.
- **Refusal entry point**: `open(to: .key(provider))` selects Jev Provider, focuses that provider's key field and,
  if empty, shows "⚠︎ No key for <provider> — paste it here." in the result slot (round-1 sheet-settings cell 2).

### AppKit facts the build must know
Menu A (`NSMenuItem.view` with an `NSSearchField` inside a real `NSMenu`), observed on macOS 26.6.2, rejected:
- The field can be made first responder of the menu's `NSPopupMenuWindow` (in `viewDidMoveToWindow`, or a timer
  in `.common` mode after `menuWillOpen`); typed characters then reach it. The window is never key → no caret, no
  focus ring. `RunLoop.perform(inModes: [.eventTracking])` from `menuWillOpen` did not run while tracking began.
- ↑/↓ are consumed by menu tracking (the field never sees `moveUp:`/`moveDown:`); after the first arrow, letters
  and ⌫ go to type-select. Enter with no highlight reaches the field as `insertNewline:`; with a highlight NSMenu
  fires that item's action. Esc is consumed by NSMenu and closes at once (`cancelOperation:` never reaches the
  field). Inserting/removing items during tracking resizes the menu live.
- Posted mouse events do not choose NSMenu items (it hit-tests the real pointer).

Menu B (built on the existing `StatusItemPanel` pattern):
- Panel: `NSPanel` `[.borderless, .nonactivatingPanel]`, `canBecomeKey = true`, `canBecomeMain = false`,
  `level = .popUpMenu`, `hidesOnDeactivate = false`, `collectionBehavior = [.canJoinAllSpaces,
  .fullScreenAuxiliary, .ignoresCycle]`, clear background + shadow. **Key focus without activating the app:**
  `makeKeyAndOrderFront(nil)` + `makeFirstResponder(field)` — no `NSApp.activate()`; the frontmost app stays
  frontmost (the Target keeps its app).
- Look: `NSVisualEffectView` `.menu` material, corner radius 10, plus a 45 % black (dark) / 30 % white (light)
  tint — the panel's `.menu` material renders lighter than a real menu without it. Rows use
  `selectedContentBackgroundColor` highlight, radius 5, `selectedMenuItemTextColor` text.
- **Keep the search field mounted**: rebuilding the view tree around it (remove/re-add) drops its field editor
  after the first character. Rebuild only the rows below it.
- Keys through the field's delegate `control(_:textView:doCommandBy:)`: `moveDown:`/`moveUp:` move our highlight
  (↑ from the first row returns to "no highlight"); `insertNewline:` chooses the highlighted row, else the first
  result row; `cancelOperation:` = Esc (below). Return `true` for handled commands so the field editor does not
  also act. Typing after arrows keeps editing the field. Put the caret at the end after setting text
  (`currentEditor()?.selectedRange`), otherwise it is all selected.
- Mouse: rows take the first click (`acceptsFirstMouse` true, `hitTest` returns the row), highlight on
  `mouseEntered` (tracking area `.activeAlways`), act on `mouseUp`.
- Choosing a row: set the Active Item, close. "Full history…" / "Settings…": close, then open Settings on the next
  run-loop turn (Settings needs `NSApp.activate()` — it is a normal window).
- Resize: after rebuilding rows, `layoutSubtreeIfNeeded`, frame = content `fittingSize`, origin under the status
  item (left edge ≈ status item's left, kept 8 pt inside the screen), top edge fixed.
- Close rules: row chosen · Esc · click outside (`resignKey` → close) · status-item click toggles (the button
  sends on `.leftMouseDown`, the item has no `menu`).
- **Open: 1-Esc vs 2-Esc.** Prototype: 1st Esc clears typed text, 2nd closes; empty field → 1st closes. Daniel did
  not decide. Recommendation: **one Esc closes**, always — it matches every macOS menu and Menu A's behaviour, and
  the text is cleared on reopen anyway.
- **Build-time verification (not done in the prototype): the auto-hiding menu bar.** The panel is not menu
  tracking, so macOS may hide the bar (and the status item) while the panel stays open; check by hand with the bar
  set to auto-hide, and decide whether the panel closes with the bar or stays.
