# Brief — Implement the SQLite history repository (issue #23)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/sqlite-history`, branch `sqlite-history` (forked from `main` at 95fb96a). Your
supervisor is the Pi session with intercom id **`01a0cac3`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks through the supervisor. One other
worker runs in parallel on the app shell — do not touch `Sources/JevPasteApp`, `Sources/MacInterop`,
`Sources/JevGateway` or their tests.

Communication protocol:
- `intercom send 01a0cac3` one line after every numbered step: `[sqlite] step N done — <fact>`.
- `intercom ask 01a0cac3` (blocking) at each **GATE**; prefix the message with `[sqlite]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never read `~/.config/jevpaste/env`. No network.

## Read first (in this order)
1. `gh issue view 23` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. `gh issue view 6 --comments` — the **storage resolution**. It is the spec: SQLite under
   `~/Library/Application Support/jevpaste/`, user-readable only; one copy = one item, no size cap; distinct =
   exact text after trimming leading/trailing whitespace, re-copy moves to top; 500 default retention, oldest
   evicted, configurable; per-item delete and clear-all; concealed never stored. Do not re-decide anything in it.
3. `gh api repos/DanielMulec/jevpaste/issues/comments/5782480932 --jq .body` — the **state-machine report**:
   `HistoryRepository` is `record`-only today, `record` is synchronous and nonisolated and called on the main
   actor, "so the adapter moves off the main actor itself". `CopyCapture` already skips concealed items.
4. `Sources/SmartPasteCore/Seams/HistoryRepository.swift`, `Sources/SmartPasteCore/Values/ClipboardItem.swift`,
   `Sources/SmartPasteCore/Capture/CopyCapture.swift`, `Tests/SmartPasteCoreTests/FakeJevAndShellPorts.swift`
   (the Core fake you will have to extend), `Sources/HistoryStore/SQLiteHistoryRepository.swift` (scaffold).
5. `gh issue view 16 --comments` (slice plan + acceptance), `gh issue view 1` **Notes** (hard rules: 400 lines/file
   incl. tests; no payloads in diagnostic logs; refer to issues by title), `CONTEXT.md` (vocabulary),
   `docs/quality-gate.md`, `docs/adr/0001-*.md`, `Makefile`.
6. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
7. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. `make check` green before every commit.
- ≤ 400 lines per file, split by concern. Descriptive names from the glossary. **No new package dependencies**:
  use the system `SQLite3` module (`import SQLite3`), wrapped behind a small, well-named layer.
- Commit small on `sqlite-history`; push after each gate. Do not merge.

## Scope
`Sources/HistoryStore/` + `Tests/HistoryStoreTests/`, plus the **minimal** extension of the Core seam
`Sources/SmartPasteCore/Seams/HistoryRepository.swift` and the matching Core test fake. The seam is Core's:
add only what Clipboard History needs and nothing SQLite-specific.

### Decisions already made for you
- **Seam extension** (propose the exact shape at GATE A): `record(_:)` stays; add reading newest-first,
  deleting one item, clearing all, and the retention limit. Because distinctness is exact trimmed text, the
  trimmed text *is* the identity: no synthetic ids in the seam. A read model that carries the copy time is fine
  if you need it; keep `ClipboardItem` unchanged.
- **Suspected secrets are not your concern.** "Stored but never sent" is enforced at paste time by the Pre-check
  slice; the repository stores every non-concealed item and carries no secret flag. Do not build detection.
- **Concealed items**: `CopyCapture` never records them, and `record` refuses them too (defence in depth).
- **Threading**: one serial queue (or actor with a synchronous hand-off) owns the connection. `record` returns
  immediately on the caller's thread; reads may block briefly (≤ 500 rows). Say so in the design doc.
- **Location**: injectable file URL; production default `~/Library/Application Support/jevpaste/history.sqlite`,
  directory created on first use, file mode 0600. Tests use a temporary directory. Schema versioned
  (`PRAGMA user_version`) so a later migration has somewhere to start.
- **Retention**: `retentionLimit` injected, default 500; eviction happens on `record`, oldest first, after dedup.
- **Diagnostics** (`os.Logger`, subsystem `jevpaste`, category `HistoryStore`): row counts, SQLite result codes
  and the file name only — never item text.

## Steps
1. `docs/design/history-store.md` (≤ 100 lines): the seam extension, schema, dedup/eviction order, threading,
   file location and permissions, what is unit-tested vs proven by the restart run. **GATE A**: ask with the path
   and the proposed seam shape.
2. Implement TDD: round trip; newest-first order; trimmed-text dedup moves to top and keeps the *latest* copy's
   exact text; retention evicts oldest and respects a custom limit; per-item delete; clear-all; concealed refused;
   empty and whitespace-only items (decide and test: refuse); large item (a few MB) round trip; corrupt/absent
   directory handled visibly (throwing init or logged failure — say which).
3. Proof: **persistence across process restart** = (a) a test that records into a temp file, drops the
   repository, opens a new instance on the same file and reads the items back; and (b) a real second-process
   check: after the test run, use the `sqlite3` CLI (or a tiny `swift run` snippet) on a file you kept, showing
   the row count. Paste the evidence (counts only) at GATE B.

## Final steps (after the slice steps above)
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files,
  and the proof evidence named above.
- Post a report comment on issue #23: what was built, the final seam shape, test count, proof evidence,
  deviations, open questions for the capture+history and history-UI slices. **GATE C**: ask with the comment
  URL, then end your turn. Do not merge.

## Report format
`[sqlite] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
