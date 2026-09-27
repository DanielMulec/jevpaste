# Menu and Settings — History Search panel, Settings window, Jev Provider keys

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
  `cancelOperation:` closes (**one Esc**). Lines (`MenuLineView`, a `FirstClickView`) take the first click and act on
  it, highlight on hover (`.activeAlways` tracking area). ⌘X/C/V/A/Z edit the field (`EditingShortcuts`: no Edit menu).
- Content (pure `HistorySearchContent`): placeholder = Active Item's first line, else "Search Clipboard History".
  Blank query → field · Settings… · Quit. Else dim "N of M matches", ≤ 5 rows 38 pt (first line; dim "N lines · age" or
  "N chars · age"; accent dot = Active Item), "No matching Clipboard Items" when none, then **Full history… (count)** ·
  Settings… · Quit (count right-aligned, right inset = titles' left inset, 25 pt).
- Logic `HistorySearchController` over `HistorySearchSurface` (AppKit: `HistorySearchPanel`); rows = `HistoryEntryRow`.
- Row → `CopyCapture.select`, close, focus back to the app frontmost at open (`TargetAppFocusReturn`), note "Active: …".
  Esc → close + focus return; click-away (resign key) → close only; Full history…/Settings… → close, then Settings
  (activates the app); Quit → terminate. Nothing is ever pasted from the panel.

## History Search seam — app-side filtering over one snapshot (Core `HistorySearch`)
- `HistoryRepository.items()` becomes `entries() -> [HistoryEntry]` (`item`, `copiedAt: Date?`): the age needs a copy
  time the store does not keep. Schema **v2**: `ALTER TABLE clipboard_item ADD COLUMN copied_at REAL` (Unix seconds;
  NULL for rows from v1 → detail without age). `record(_:copiedAt:)`: Copy Capture stamps it from its injected `now`.
- `HistorySearch.results(for:in:)` → newest ≤ 5 (`rowLimit`) matches, match count, history count; `nil` when blank.
  Trimmed query, case- and diacritic-insensitive substring of the whole text, as the old panel. `entries()` is read at
  open and on an Active Item change while open, then filtered in memory per keystroke. Not SQL: `LIKE`/`lower()`/`instr`
  fold ASCII only ("ä" ≠ "Ä") and `trim()` strips spaces only; ≤ 500 rows; stays pure in Core.

## Jev Provider, credentials and the per-attempt read
- Core `JevProvider` (`vercelAIGateway` "Vercel AI Gateway" — default, `typesafeDirect` "Typesafe direct"). Core seam `JevProviderAccess.openForPasteAttempt() -> JevProviderOpening` (`.ready(any DecisionService)` |
  `.noKey(JevProvider)`), replacing `PasteAttemptPorts.decisionService`. Called **once at ⌘⇧V** (after "Nothing copied
  yet"); the service is pinned in the attempt and serves every step (decision 9). `.noKey` → refusal, no Target read.
- JevGateway: `JevCredentials { apiKey(for: JevProvider) -> String? }`; `JevGatewayAccess(credentials:choice:transport:)`
  reads the choice and its key once and returns `JevGatewayDecisionService(apiKey:transport:)`. `missingKey` and the
  env-file read leave the request path. Test: `JevGatewayAccess.testConnection(of:)` sends one step-shaped request (one
  choice question, one option) with the saved key through the same exchange → `.works` | `.failed(reason)`.
- Choice persisted in UserDefaults (`jevProvider`, raw value); unknown or not-yet-built values read as the default.
  Typesafe direct is listed, disabled (radio + key row) until [Add Typesafe direct as a Jev Provider](https://github.com/DanielMulec/jevpaste/issues/54).
- Key store (`FileJevKeyStore`, app layer, Daniel 2026-09-27): `~/.config/jevpaste/keys/<provider raw value>`, UTF-8
  key, file 0600; every write first insists the directory is a real directory owned by the user (no symlink) and
  tightens it to 0700, then writes a new 0600 file whole (short writes/EINTR retried) and renames it over; empty → unlink.
  Keys never logged (errno only). Tests: temp directory; elsewhere an in-memory fake.
- Capture exclusion (Daniel 2026-09-27): a copy (live or Launch Adoption) whose trimmed text equals a stored key is
  adopted concealed — never in history. Core seam `CaptureExclusion`; `StoredKeyCaptureExclusion` reads the store per copy.
- Not the Keychain (2026-09-27): self-signed `jevpaste-dev` has no Team ID → each rebuild prompts (XARA partition =
  creator cdhash). `KeychainJevKeyStore` stays unused (`periphery:ignore:all`) for a Team-ID-signed build.
- One-time import (`JevKeyImport`, at launch): flag `jevProviderKeyImportDone` set → nothing (env file never read
  again). Else the store has a Vercel key → set flag (`storeHasKey`); else env file has `AI_GATEWAY_API_KEY` → store,
  set flag on success (`imported`), leave unset on failure (`failed`, retried next launch); else set flag (`noEnvKey`).
  Env file never deleted. Log: `key import <result>`, `launch provider=… apiKeyPresent=…`, "copy of a stored key kept…".

**Refusal "No key for <provider> — open Settings"**: `refused(.noProviderKey(JevProvider))`, log `outcome
refused.noProviderKey`, shown 5 s; while shown a click opens Settings on Jev Provider, key field focused, "⚠︎ No key for
<provider> — paste it here." (`IndicatorPresenter.opensSettingsToKey`; every other outcome stays click-inert).

## Settings window (`JevPasteApp/Settings/`)
`NSTabViewController` `.toolbar`: **General** (Open at Login switch over `LoginItemToggle`, state read on appear;
"approve in System Settings" note) · **Jev Provider** (radios, one-line "no silent switch" hint, per provider: secure
field ⇄ plain field via eye button, Test, inline result "Testing…" / green "✓ Works — Jev answered through <p>." / red
"✕ <reason>"; every edit saves the key and clears the result) · **Full History** (inset table, two-line rows,
"Active" capsule following `ActiveItemChange`, ✕ per row, footer "N Clipboard Items" + "Clear History…" → sheet with
destructive Clear History / Cancel). One instance; height follows the tab, top edge fixed; ⌘W closes, ⌘X/C/V/A/Z edit;
closing hides the app so focus returns. Active Item changes fan out in the shell (`ActiveItemChanges`): one Core
observer, listeners = notice, panel, Full History.

## Tests
Core: `HistorySearchTests` (≤ 5 newest, counts, case/diacritic, blank, trimmed query) · `JevProviderAccessTests`
(noKey refusal before Target/Jev; one open per attempt; a changed choice mid-attempt ignored, next attempt uses it).
HistoryStore: `copied_at` stamped/read, v1 → v2 keeping rows (NULL age), v3 refused. JevGateway: access ready/noKey,
key sent as Bearer, connection test per status. App: `HistorySearchContentTests`, `HistorySearchControllerTests`
(keys, Enter fallback, one Esc, click-away, routing, refresh on copy), `JevKeyImportTests`, `JevProviderChoiceTests`,
`ProviderKeySettingsTests`, `FullHistoryListTests`, `NoProviderKeyRefusalTests`, `FileJevKeyStoreTests` (loose dir,
symlink, short writes), `StoredKeyCaptureExclusionTests`; Core `CaptureExclusionTests`. Live: AppKit, bar.

## Live run (after the install gate; synthetic `JEVPASTE-MENU-53` rows only)
0. Two installs: `key import imported`, then the rebuild reads the file (no prompt). a. Panel: placeholder, type,
↓ then a letter keeps editing, click row, reopen shows it. b. ⌘⇧V in a Chrome `data:` field pastes it. c. Key present,
Test ✓. d. Clear key → ⌘⇧V refusal → click → Settings on the key; restore = clear the import flag, relaunch (re-import
from the env file). e. Open at Login off/on. f. Delete the staged row; Clear History… → Cancel. g. Auto-hide bar.
