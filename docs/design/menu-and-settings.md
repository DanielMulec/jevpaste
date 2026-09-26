# Menu and Settings — History Search panel, Settings window, keys in the Keychain

Slice: [Implement the status-item menu with History Search and the Settings window](https://github.com/DanielMulec/jevpaste/issues/53).
Decisions: [Decide how JevPaste supports Typesafe direct alongside the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/45#issuecomment-5849649811)
(2–6, 9) and [Prototype the status-item menu with History Search and the Settings window](https://github.com/DanielMulec/jevpaste/issues/37#issuecomment-5850253565).
Supersedes [history-ui.md](history-ui.md) (panel removed; its Core seam `select(_:)`/`ActiveItemChange` stays).

## History Search panel (`JevPasteApp/HistorySearch/`)
- A status-item click (button action on `.leftMouseDown`, no `NSMenu`) toggles a menu-shaped panel. A text field inside
  a real `NSMenu` is never key (no caret) and goes deaf after one ↑/↓ (type-select takes the letters) — #37 fact table.
- Panel = the shared `StatusItemPanel` (`[.borderless, .nonactivatingPanel]`, key-capable, never main,
  `hidesOnDeactivate = false`), here at `.popUpMenu` level, `HUDBackgroundView` in `.menu` material, radius 10, plus a
  tint (45 % black dark / 30 % white light — the panel's `.menu` renders lighter than a real menu). Key focus without
  activating: `makeKeyAndOrderFront` + `makeFirstResponder(field)`, never `NSApp.activate()`.
- Placement: left edge ≈ the status item's, 8 pt inside the screen; after every rebuild `fittingSize`, **top edge
  fixed** (`StatusItemPanel.resizeKeepingTopEdge`). The field stays mounted: rebuilding around it drops its field
  editor after one character; only the rows below it are rebuilt. Caret put at the end after setting text.
- Keys via the field delegate `control(_:textView:doCommandBy:)`, returning `true` when handled: ↓/↑ move the highlight
  over rows and menu items (↑ on the first → none); `insertNewline:` chooses the highlighted item, else the first row;
  `cancelOperation:` closes (**one Esc**). Rows take the first click (`acceptsFirstMouse`, `hitTest` → row), highlight
  on hover (`.activeAlways` tracking area), act on mouse-up. ⌘X/C/V/A/Z edit the field (no Edit menu in an accessory app).
- Content (pure `HistorySearchContent`): placeholder = Active Item's first line, else "Search Clipboard History".
  Blank query → field · Settings… · Quit. Else dim "N of M matches", ≤ 5 rows 38 pt (first line; dim "N lines · age" or
  "N chars · age"; accent dot = Active Item), "No matching Clipboard Items" when none, then **Full history… (count)** ·
  Settings… · Quit (count right-aligned, right inset = titles' left inset, 25 pt).
- Row → `CopyCapture.select`, close, focus back to the app frontmost at open (`TargetAppFocusReturn`), note "Active: …".
  Esc → close + focus return; click-away (resign key) → close only; Full history…/Settings… → close, then Settings
  (activates the app); Quit → terminate. Nothing is ever pasted from the panel.

## History Search seam — app-side filtering over one snapshot (Core `HistorySearch`)
- `HistoryRepository.items()` becomes `entries() -> [HistoryEntry]` (`item`, `copiedAt: Date?`): the age needs a copy
  time the store does not keep. Schema **v2**: `ALTER TABLE clipboard_item ADD COLUMN copied_at REAL` (Unix seconds;
  NULL for rows from v1 → detail without age). `record` stamps it through an injected `now`.
- `HistorySearch.results(for: query, in: entries, limit: 5)` → newest ≤ 5 matches, match count, history count.
  Query trimmed of whitespace and newlines in Swift; match = case- and diacritic-insensitive substring of the whole
  text (Foundation), as the old panel did. The panel reads `entries()` once when it opens and again on an Active Item
  change while open, then filters in memory per keystroke.
- Why not SQL: SQLite's `LIKE`, `lower()` and `instr` fold ASCII only ("ä" ≠ "Ä", no diacritic folding) and `trim()`
  strips spaces only; matching the old semantics in SQL needs a C-callback function. ≤ 500 rows, one read per open
  (the old panel read everything per keystroke). Search stays pure and tested in Core without SQLite.

## Jev Provider, credentials and the per-attempt read
- Core `JevProvider` (`vercelAIGateway` "Vercel AI Gateway" — default, `typesafeDirect` "Typesafe direct").
- Core seam `JevProviderAccess.openForPasteAttempt() -> JevProviderOpening` (`.ready(any DecisionService)` |
  `.noKey(JevProvider)`), replacing `PasteAttemptPorts.decisionService`. Called **once at ⌘⇧V** (after "Nothing copied
  yet"); the service is pinned in the attempt and serves every step (decision 9). `.noKey` → refusal, no Target read.
- JevGateway: `JevCredentials { apiKey(for: JevProvider) -> String? }`; `JevGatewayAccess(credentials:choice:transport:)`
  reads the choice and its key once and returns `JevGatewayDecisionService(apiKey:transport:)`. `missingKey` and the
  env-file read leave the request path. Test: `JevConnectionTest` sends one step-shaped request (one choice question,
  one option) through the same exchange → `.works` | `.failed(reason)` (key rejected, rate limited, offline, HTTP n).
- Choice persisted in UserDefaults (`jevProvider`, raw value); unknown or not-yet-built values read as the default.
  Typesafe direct is listed, disabled (radio + key row) until [Add Typesafe direct as a Jev Provider](https://github.com/DanielMulec/jevpaste/issues/54).
- Keychain (`KeychainJevKeyStore`, Security framework, app layer): generic password, service `com.jevpaste.JevPaste.jev-provider-key`,
  account = provider raw value, label "JevPaste — <provider> API key", data = UTF-8 key; add, update (`SecItemUpdate`),
  delete when the field is emptied. Keys never logged; errors log `OSStatus` only. Tests use an in-memory fake.
- One-time import (`JevKeyImport`, at launch): flag `jevProviderKeyImportDone` set → nothing (env file never read
  again). Else Keychain has a Vercel key → set flag (`keychainHasKey`); else env file has `AI_GATEWAY_API_KEY` → store,
  set flag on success (`imported`), leave unset on failure (`failed`, retried next launch); else set flag (`noEnvKey`).
  The env file is never deleted. Log: `key import <result>`, `launch provider=… apiKeyPresent=…` (booleans/enums).

**Refusal "No key for <provider> — open Settings"**: Core outcome `refused(.noProviderKey(JevProvider))`, log `outcome refused.noProviderKey`. Shown 5 s; while shown, a
click on the indicator opens Settings on Jev Provider with that key field focused and "⚠︎ No key for <provider> —
paste it here." in its result slot (presenter gets an `openSettingsToKey` closure; other outcomes stay click-inert).

## Settings window (`JevPasteApp/Settings/`)
`NSTabViewController` `.toolbar`: **General** (Open at Login switch over `LoginItemToggle`, state read on appear;
"approve in System Settings" note) · **Jev Provider** (radios, one-line "no silent switch" hint, per provider: secure
field ⇄ plain field via eye button, Test, inline result "Testing…" / green "✓ Works — Jev answered through <p>." / red
"✕ <reason>"; every edit saves to the Keychain and clears the result) · **Full History** (inset table, two-line rows,
"Active" capsule following `ActiveItemChange`, ✕ per row, footer "N Clipboard Items" + "Clear History…" → sheet with
destructive Clear History / Cancel). One instance; height follows the tab, top edge fixed; ⌘W closes, ⌘X/C/V/A/Z edit;
closing hides the app so focus returns. Active Item changes fan out in the shell (`ActiveItemChanges`): one Core
observer, listeners = notice, panel, Full History.

## Tests
Core: `HistorySearchTests` (≤ 5 newest, counts, case/diacritic, blank, trimmed query) · `JevProviderAccessTests`
(noKey refusal before Target/Jev; one open per attempt; a changed choice mid-attempt ignored, next attempt uses it).
HistoryStore: `copied_at` stamped/read, v1 → v2 keeping rows (NULL age), v3 refused. JevGateway: access ready/noKey,
key sent as Bearer, connection test mapping per status. App: content mapping + age formatting, controller over a fake surface (keys, Enter fallback, one Esc, click-away no focus return, choose selects,
Settings/Full history/Quit routing, refresh on copy), import (four branches, env never read after flag), Settings models
(choice store, edit clears result, test states, Full History delete/clear/active tag), refusal text/log/click → key. Live only: AppKit rendering, Keychain calls, hover, auto-hiding bar.

## Live run (after the install gate; synthetic `JEVPASTE-MENU-53` rows only)
0. Two `make install`s before Daniel: the second build reads the Keychain item without a prompt (probe first with
   `kSecUseAuthenticationUIFail` in a throwaway signed binary: partition list of an item made by a jevpaste-dev app).
a. Panel: placeholder, type, ↓ then a letter keeps editing, click row, reopen shows it. b. ⌘⇧V in a Chrome `data:`
field pastes the staged value. c. Settings key present, Test ✓. d. Clear key → ⌘⇧V refusal → click → Settings on the
key; restore by clearing the import flag and relaunching (the app re-imports from the env file; key never shown).
e. Open at Login off/on. f. Delete the staged row; Clear History… → Cancel. g. Auto-hiding menu bar, Daniel's words.
