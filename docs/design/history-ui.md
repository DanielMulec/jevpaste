# History UI — select, delete and clear Clipboard History

> **Superseded** by [menu-and-settings.md](menu-and-settings.md) (#53): the panel below is removed; its Core seam stays.

Slice: [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27). Decision and prototype:
[Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9).

## Core seam (`SmartPasteCore/Capture/`, TDD, `Tests/SmartPasteCoreTests/ActiveItemSelectionTests`)
- `CopyCapture.select(_ item: ClipboardItem)`: the item becomes the Active Item. No history write, no reorder,
  no clipboard write (ordinary ⌘V still pastes the clipboard). Stays Active until the next copy or selection.
- Port: `CopyCapture.observeActiveItemChanges(_ onChange: @MainActor (ActiveItemChange) -> Void)`, one observer
  (the shell), same shape as `Clipboard.startObservingChanges`. `ActiveItemChange` = `item` + `cause`
  (`.copied` | `.selected`). Launch Adoption happens before anyone observes and is not reported.
- Tests: select → Active, `recordedItems` and order unchanged · a later copy replaces a selection · a selection
  during a Paste Attempt leaves the pinned item alone (that attempt pastes the pinned item, the next one the
  selection) · deleting the Active Item from history keeps it Active and ⌘⇧V still pastes it · the attempt's own
  write/restore leaves a selection Active · the observer hears copies and selections with their cause.

## Panel anatomy (screenshots: `~/.pi/worktrees/jevpaste/history-ui-screens/{light,dark,dark-confirm}.png`)
Key-capable non-activating `StatusItemPanel` under the status item (chooser parts: `StatusItemPanel`,
`StatusItemPlacement`, `HUDBackgroundView` — gains `material:`/`cornerRadius:` defaults, used with `.popover`,
which follows light/dark). 520 pt wide, top to bottom:
1. Search field, 20 pt light, magnifier symbol, placeholder "Search Clipboard History"; filters as you type
   (case- and diacritic-insensitive substring over the whole item text).
2. Active card, pinned, accent-tinted: `pin.fill` badge, caption "ACTIVE · ⌘⇧V PASTES THIS", first 3 non-blank
   lines (first semibold) + "N more lines". States: text / "Concealed item — not shown" / "Nothing copied yet".
3. Rows: inset table, fixed height of 9 rows (scrolls beyond), newest first. Row = symbol (`textformat` single
   line, `text.alignleft` multi-line), first non-blank line, "N lines", accent ✓ on the Active Item's row, ✕ on
   hover. Highlight = accent selection. Empty: "No History Yet" / "No Matches".
4. Footer: key caps "↩ Make Active · ⌘⌫ Delete · esc Close", right "Clear History…". Confirmation replaces the
   footer inline: "Delete all N items from history?" [Cancel] [Clear History] (red). The Active Item stays.
States: `closed` → `open(query, highlighted, confirmingClearAll)` → `closed`; events only while open.

## Key map (search field keeps first responder; keys arrive as editing commands)
↑/↓ move the highlight (clamped) · Return/Enter select it (ignored while the clear question shows) · click a row selects it · ⌘⌫ deletes the highlighted
row · ⌫ deletes it only when the search field is empty and the key is not auto-repeating (holding ⌫ to clear a
query never runs on into history) · ✕ deletes that row · Esc closes (or cancels an open clear confirmation) ·
click-away closes; ⌘X/C/V/A/Z edit the query (no Edit menu in an accessory app). Select → `select(_:)`, close, `TargetAppFocusReturn` to the app frontmost at open, and the
observer shows "Active: <first line ≤ 40 chars>" (`pin.fill`, 2.5 s) via `IndicatorNoticeSurface`, so it waits
behind a paste outcome and never covers it. Esc → close + focus return, no change. Click-away → close, no focus
return (the user clicked where they want to be), no change. A copy while open refreshes the panel; the highlight stays on the same item.

## Opening
Status-item menu: "Clipboard History…" / — / "Open at Login" / — / "Quit". Opens after the menu closes.
**Hotkey: none (proposal).** `GlobalHotkey` is fixed to ⌘⇧V; a second shortcut means a MacInterop change, a
collision choice and another failure notice — not free. Follow-up ticket if Daniel wants one.

## Files (`Sources/JevPasteApp/HistoryPanel/`, each < 200 lines)
`HistoryPanelContent` (pure mapping) · `HistoryPanelSurface` (protocol + events) · `HistoryPanelController`
(logic over the surface, `HistoryRepository`, `CopyCapture`, `TargetAppFocusReturn`, frontmost pid, notices) ·
`HistoryPanel` (AppKit surface) · `ActiveItemView` · `HistoryRowsView` · `HistoryRowCell` · `HistoryPanelFooter` ·
`History/IndicatorNotice+Selection`. Touched: `CopyCapture`, `StatusItemPanelParts`, `MenuBarDelegate`,
`SmartPasteApplication`, `IndicatorNotice` (non-warning init). Not touched: `PasteAttempt/*`, `OutcomeMessage`.
Unit (`JevPasteAppTests`, fakes + `SteppedClock`): content mapping, controller (every key/event above, focus
return, note, confirmation, refresh on copy, events after close ignored). Live only: AppKit rendering, hover, keys.
Log (`jevpaste`/`HistoryPanel`, ints/enums only): opened rows=N, selected row i, deleted, cleared N, dismissed
(esc|click-away), focus return result. Never item text.

## Live run for Daniel (synthetic rows, one pure value per line, marker on its own line)
Setup (supervisor, `pbcopy` ~1 s apart): `JEVPASTE-HIST-ONE⏎alpha.one@example.org`, `…-TWO⏎beta.two@example.net`,
`…-THREE⏎gamma.three@example.com` (THREE Active). Chrome page: "Email address" textarea + a plain paragraph.
1. Click into the textarea. Icon › "Clipboard History…": the Active card shows THREE. *Why: Active at a glance.*
2. Type `one`, Enter: panel closes, note "Active: JEVPASTE-HIST-ONE". *Why: obvious selection feedback.*
3. Without clicking, type `x`: it lands in the textarea; delete it. *Why: focus returns to the target.*
4. ⌘⇧V: `alpha.one@example.org`, "Pasted". *Why: Rejev-paste — the selected older item is what pastes.*
5. Click the paragraph, ⌘⇧V: "No text field focused". Open the panel: ONE still Active; Esc. *Why: a refusal
   leaves the selection Active.*
6. Supervisor copies `JEVPASTE-HIST-FOUR⏎delta.four@example.com`; open the panel: FOUR Active; Esc; ⌘⇧V in the
   textarea: `delta.four@example.com`. *Why: a fresh copy replaces a selection.*
7. Open the panel, hover TWO, click ✕; highlight THREE, ⌘⌫: both gone. *Why: delete is easy to find.*
8. Click "Clear History…", read the question, click **Cancel** (real history!). *Why: clear-all is findable and
   guarded.* 9. Open, click into Chrome: panel closes, nothing changed. *Why: click-away is harmless.*
