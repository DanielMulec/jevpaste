# Capture and history — persistent Clipboard History in the app

Slice: [Add clipboard capture and persistent history](https://github.com/DanielMulec/jevpaste/issues/25). Builds on
[Implement the SQLite history repository](https://github.com/DanielMulec/jevpaste/issues/23) and the
[Tracer bullet](https://github.com/DanielMulec/jevpaste/issues/24). Core ports unchanged; no history UI.

## Composition (`SmartPasteApplication`, only the history/capture lines change)
- `panel` → `IndicatorNoticeSurface(wrapping: panel, clock:)` → `IndicatorPresenter(surface: noticeSurface, …)`.
  The presenter line changes only its `surface:` argument; `chooser:` and the presenter files stay untouched.
- `history = ClipboardHistoryOpening.open(notices: noticeSurface)`: tries `SQLiteHistoryRepository(fileURL:
  HistoryStoreLocation.defaultFileURL, retentionLimit: 500, onFailure:)`; on throw returns
  `UnavailableHistoryRepository` (the renamed interim discarding type, moved to `JevPasteApp/History/`).
- `CopyCapture(clipboard:history:contentsAtLaunch: { clipboard.currentItem() })`.

## Failure paths and their visible form (`IndicatorNotice+History`, pure mapping)
| path | log (`jevpaste`/`History`, kinds only) | indicator | duration |
|---|---|---|---|
| init throws | failure kind + file name | `exclamationmark.triangle` "History unavailable — <reason>" | 5 s |
| `onFailure`, operation `items` | kind | "History read failed" | 2.5 s |
| `onFailure`, any other operation (record, evict, delete, clearAll, …) | kind | "History write failed" | 2.5 s |

Reasons: folder not usable / file not created / file permissions not set / file could not be opened (`open`) /
file is not a database (result 26) / written by a newer version / database error <code>. The app keeps running;
Smart Paste works on the Active Item without history. HistoryStore already logs the SQLite details.

## Notice vs. a running Paste Attempt — **defer**
`IndicatorNoticeSurface` is an `IndicatorSurface` decorator; the presenter keeps sole ownership of attempt states.
- It forwards `display`/`hide`/`forwardClicks` and tracks whether the presenter is showing anything
  (processing, retrying **or** an outcome).
- `show(notice)`: presenter idle → display it and schedule its hide; presenter busy → keep it pending (only the
  newest pending notice; older ones are logged already) and display it when the presenter next calls `hide()`.
- A presenter `display` while a notice is up replaces it and cancels the notice's hide timer; a stale presenter
  `hide()` (presenter shows nothing) is ignored, so it never cuts a notice short.
- Clicks on a notice reach the presenter, which ignores them outside processing/retrying.
Deferred, not dropped: a failed write during the Restore Window would otherwise be invisible.

## Launch Adoption (GATE A decision; confirmed by Daniel)
Rule: the text on the clipboard at launch is treated exactly like a live copy — it becomes the Active Item and is
recorded unless concealed; no text (empty clipboard, image only) → no Active Item.
Shape (deviation from the brief's "init takes `snapshot()`"): `ClipboardSnapshot` is opaque to Core, and turning
it into an item needs the plain-text type and the concealed-marker list, both in MacInterop, and #6 requires the
marker check *before* reading content. So the adapter derives the item and Core receives it:
- MacInterop: the existing private `SystemClipboard.currentItem(on:)` becomes `public func currentItem() ->
  ClipboardItem?` (not on the `Clipboard` port; markers checked first, as for polling).
- Core (`CopyCapture` only): `init(clipboard:history:contentsAtLaunch: @MainActor () -> ClipboardItem?)`, called
  **after** `startObservingChanges` (whose baseline is the change count at subscription): a copy landing before
  the baseline is adopted at launch, never lost; one landing between baseline and read is adopted at launch and is
  reported once more by the poll — a same-identity re-copy (upsert to top), harmless. Launch Adoption and live
  copies share `adopt(_:)`.

## Threading
`onFailure` runs on the repository's serial queue. The handler only captures the `@MainActor` notice surface and
does `Task { @MainActor in noticeSurface.show(IndicatorNotice(historyRuntimeFailure: failure)) }`. It never calls
`items()` or any repository method. Everything else is on the main actor as before.

## Tested vs live-proven
- Core (`LaunchAdoptionTests`, fake clipboard + `FakeHistoryRepository`): launch text → active + recorded;
  concealed → active, not recorded; `nil` → no Active Item, nothing recorded; a later live copy replaces it.
- MacInterop: `currentItem()` over a scratch pasteboard: text; marked → concealed; no text → `nil`.
- Shell (`Tests/JevPasteAppTests`): `IndicatorNotice+History` mapping (every failure kind, read vs write); the surface over
  `RecordingIndicatorSurface` + `SteppedClock` (idle show + hide at 2.5/5 s; deferred behind processing/retrying/
  outcome, shown after the presenter hides; presenter replaces a notice and the old timer does not hide it);
  `UnavailableHistoryRepository` keeps nothing; the failure handler called off the main thread delivers the mapped
  notice on the main actor; opening with an unusable file URL (directory in the way) yields the fallback + notice.
- Live only: the real file `~/Library/Application Support/jevpaste/history.sqlite`, panel rendering, Launch
  Adoption from the general pasteboard.

## Live-run plan (step 3; ask before `make install`)
1. `make install`, launch; `log show` for `jevpaste` History lines (no failure expected).
2. Daniel copies `JEVPASTE-HISTORY-ALPHA Wren Castellan`, then `JEVPASTE-HISTORY-BETA wren.castellan@example.net`;
   quits via the menu; relaunches.
3. I read only synthetic rows: `sqlite3 <file> "SELECT trim(text) FROM clipboard_item WHERE text LIKE
   'JEVPASTE-HISTORY-%' ORDER BY copy_sequence DESC"` (expected BETA, ALPHA) — never Daniel's own copies.
4. Launch Adoption: app quit; Daniel copies `Tamsin Vorlage` / `tamsin.vorlage@example.com` / `+49 40 5550 9876`;
   launches; opens the tracer bullet's Chrome `data:` "Email address" textarea; ⌘⇧V → `tamsin.vorlage@example.com`
   inserted, ✓. I quit the app.
