# HistoryStore — the SQLite `HistoryRepository` adapter

Slice: [Implement the SQLite history repository](https://github.com/DanielMulec/jevpaste/issues/23). Spec:
[Choose clipboard-history storage and practical secret protection](https://github.com/DanielMulec/jevpaste/issues/6)
(storage resolution). Starting point: the `record`-only seam from
[Implement the Paste Attempt state machine over the seams](https://github.com/DanielMulec/jevpaste/issues/18).

## Seam extension (Core, `Seams/HistoryRepository.swift`)
```swift
public protocol HistoryRepository: Sendable {
    /// Stores a newly copied Clipboard Item; returns at once. Concealed, empty and whitespace-only items are
    /// refused. A re-copy of a distinct item replaces it and moves it to the top. Evicts the oldest beyond the limit.
    func record(_ item: ClipboardItem)
    /// Clipboard History, newest first, at most `retentionLimit` items. May block briefly.
    func items() -> [ClipboardItem]
    /// Removes the item whose trimmed text equals `item`'s trimmed text; no-op if absent.
    func delete(_ item: ClipboardItem)
    /// Removes every item.
    func clearAll()
    /// Changes how many distinct items are kept (minimum 1); a lower limit evicts the oldest at once.
    func changeRetentionLimit(to limit: Int)
}
```
- Identity = trimmed text (leading/trailing `whitespacesAndNewlines`), compared **byte-exact** (UTF-8), in line
  with the byte-exact Candidate rules. No synthetic id, no copy time in the seam: order is all the History UI
  needs today. `ClipboardItem` unchanged; returned items have `isConcealed == false`.
- The retention limit is also an init parameter (default 500). Persisting the chosen value is the settings
  UI's job, not the repository's; the shell passes it in at launch and calls `changeRetentionLimit` on change.
- No secret flag: "stored but never sent" is the Pre-check's job at paste time.
- The Core fake `FakeHistoryRepository` gains the four members (in-memory, same semantics where cheap).

## Schema (version 1, `PRAGMA user_version = 1`)
```sql
CREATE TABLE clipboard_item (
    distinct_key  BLOB    PRIMARY KEY,   -- SHA-256 of the trimmed text's UTF-8 bytes
    text          TEXT    NOT NULL,      -- exact text of the latest copy, untrimmed
    copy_sequence INTEGER NOT NULL       -- strictly increasing; the newest copy has the largest
);
CREATE INDEX clipboard_item_by_copy_sequence ON clipboard_item (copy_sequence);
```
- A hash key instead of the trimmed text keeps multi-MB items from being stored twice (column + index).
  `CryptoKit` is a system framework, not a package dependency.
- `copy_sequence` (not wall-clock time) orders items, so a clock change cannot reorder history.
- Opening: `user_version` 0 → create schema and set 1; 1 → use; anything else → init throws
  (`unsupportedSchemaVersion`), leaving the file untouched. Later migrations start from this switch.

## `record` order (one transaction)
1. Refuse concealed, empty or whitespace-only items (logged as a refusal kind, no text).
2. Upsert by `distinct_key`: new sequence = max + 1; on conflict replace `text` and `copy_sequence`
   (dedup keeps the *latest* copy's exact text and moves it to the top).
3. Evict: delete every row outside the newest `retentionLimit` by `copy_sequence`. Dedup therefore never
   evicts an item it is about to move up.

## Threading
`SQLiteHistoryRepository` is a `final class`, `Sendable`. One serial `DispatchQueue` owns the single SQLite
connection (a confined `SQLiteConnection`, `@unchecked Sendable`, only touched on that queue).
`record`, `delete`, `clearAll`, `changeRetentionLimit` enqueue with `queue.async` and return at once on the
caller's thread (main actor included). `items()` uses `queue.sync` and may block the caller briefly
(≤ 500 rows); because the queue is serial, a read sees every write enqueued before it. No `async` in the seam.

## File location and permissions
- Injectable `fileURL`. Production default:
  `~/Library/Application Support/jevpaste/history.sqlite` (`FileManager` application-support directory).
- The directory is created on first use with mode `0700`; the file is set to `0600` after open (also
  tightening an existing file). Rollback journal (default `DELETE` mode) so no `-wal`/`-shm` side files
  linger; SQLite gives the journal the database file's mode.
- No at-rest encryption (resolution: single-user Mac, FileVault).

## Failures (visible, never silent)
- `init(fileURL:retentionLimit:) throws HistoryStoreFailure`: directory not creatable, file not openable,
  not a database (corrupt), unsupported schema version. The shell shows the indicator; Core is unaffected.
- After a successful open, a failing statement is logged (operation + SQLite result code) and the write is
  lost; `items()` returns what it could read (empty on failure). Surfacing runtime write failures in the UI
  is an open question for the capture+history slice.
- Diagnostics: `os.Logger` subsystem `jevpaste`, category `HistoryStore`: operation, row counts, SQLite
  result codes and the file *name*. Never item text or keys.

## Files (each ≤ 400 lines)
`SQLiteHistoryRepository.swift` (seam + queue), `SQLiteConnection.swift` (thin `SQLite3` wrapper: open,
prepare/bind/step, transactions, result codes), `HistoryStoreSchema.swift` (DDL, `user_version`),
`DistinctKey.swift` (trimming + hash), `HistoryStoreFailure.swift`, `HistoryStoreLocation.swift` (default URL,
directory/file modes). Tests split by concern: recording/order/dedup, retention, deletion, refusal,
persistence and failures.

## Tested vs proven
- **Unit (`swift test`, real SQLite in a temporary directory):** round trip; newest-first; trimmed dedup moves
  to top and keeps the latest exact text; retention evicts oldest and honours a custom and a lowered limit;
  per-item delete; clear-all; concealed, empty and whitespace-only refused; a multi-MB item round trips;
  absent parent directory is created; a non-database file and a directory-in-the-way make init throw; file
  mode 0600; a new instance on the same file reads the items back (restart within one process).
- **Restart run (second process):** a test run records into a kept file; then the `sqlite3` CLI opens it in
  a new process and counts rows. Counts only, no text.
- **Not covered here:** wiring into `CopyCapture` and the shell (capture+history slice), History UI.
