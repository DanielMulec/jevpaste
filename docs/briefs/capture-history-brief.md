# Brief — Add clipboard capture and persistent history (issue #25)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/capture-history`, branch `capture-history` (forked from `main`). Your supervisor is
the Pi session with intercom id **`01a0cc6f`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use
exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks through the supervisor. **One other
worker runs in parallel on the Candidate Chooser UI** — see "Shared files" below.

Communication protocol:
- `intercom send 01a0cc6f` one line after every numbered step: `[capture] step N done — <fact>`.
- `intercom ask 01a0cc6f` (blocking) at each **GATE**; prefix the message with `[capture]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 25` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. `gh api repos/DanielMulec/jevpaste/issues/comments/5783906606 --jq .body` — the **SQLite history report**:
   `SQLiteHistoryRepository(fileURL:retentionLimit:onFailure:)` throws on an unusable file; `onFailure` runs
   **on the repository's serial queue** — never call `items()` from inside it.
3. `gh api repos/DanielMulec/jevpaste/issues/comments/5783953394 --jq .body` — the **tracer-bullet report**
   (the shell you extend; open question: pre-launch clipboard not seeded).
4. `gh issue view 6 --comments` — storage/secret decisions (concealed items never stored). Do not re-decide.
5. The sources: `Sources/SmartPasteCore/Capture/CopyCapture.swift`, `Sources/SmartPasteCore/Seams/Clipboard.swift`,
   `Sources/SmartPasteCore/Seams/HistoryRepository.swift`, `Sources/SmartPasteCore/Values/ClipboardItem.swift`,
   `Sources/HistoryStore/*.swift`, `Sources/JevPasteApp/**/*.swift`, `docs/design/app-shell.md`,
   `docs/design/history-store.md`, `Tests/SmartPasteCoreTests/FakeSystemPorts.swift`.
6. `gh issue view 16 --comments` (slice plan + acceptance), `gh issue view 1` **Notes** (hard rules: 400 lines/file
   incl. tests; no secrets in source; no payloads in diagnostic logs; refer to issues by title), `CONTEXT.md`,
   `docs/quality-gate.md`, `Makefile`.
7. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
8. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. `make check` green before every commit.
- ≤ 400 lines per file, split by concern. Descriptive names from the glossary. No new dependencies without `ask`.
- Core ports stay as they are. The only Core change allowed is inside `CopyCapture` (seeding, step 1 decision).
- Commit small on `capture-history`; push after each gate. Do not merge.

## Shared files (parallel worker on the chooser)
The chooser worker deletes `Interim/UnbuiltCandidateChooser.swift`, removes the interim chooser lines from
`Indicator/IndicatorPresenter.swift` and `Indicator/OutcomeMessage.swift`, and changes the `chooser:` line of
`SmartPasteApplication.swift`. You therefore:
- touch `SmartPasteApplication.swift` **only** where the history/capture is built (the `capture` line and what it
  needs); keep the diff there minimal;
- do **not** edit `IndicatorPresenter.swift` or `OutcomeMessage.swift`. Put the history-failure notice in a new
  file (e.g. `Indicator/IndicatorPresenter+History.swift` or a small `HistoryFailureNotice` type that renders through
  the existing `IndicatorSurface`/presenter API). If the presenter truly needs a new method, `ask` first;
- never touch `Interim/UnbuiltCandidateChooser.swift` or anything under a future `Chooser/` directory;
- `~/Applications/JevPaste.app` is shared: `make install` **only** when the supervisor's gate reply says go.

## Scope
1. **Persistent history in the app.** Replace `DiscardingHistoryRepository` with
   `SQLiteHistoryRepository(fileURL: HistoryStoreLocation.defaultFileURL, retentionLimit: 500, onFailure:)` in
   the composition root. If the init throws: log the failure kind (`os.Logger`, subsystem `jevpaste`, never the
   path's contents beyond the file name), show a **visible** indicator ("History unavailable — <short reason>")
   and keep running **without** history (a discarding repository is the fallback — rename the interim type to
   say so, e.g. `UnavailableHistoryRepository`, and move it out of `Interim/`). Smart Paste must still work.
2. **Runtime failures visible.** `onFailure` fires on the repository's queue; hop to the main actor and show a
   short notice on the indicator ("History write failed" / "History read failed") for ~2.5 s. Must not disturb a
   running Paste Attempt's indicator: if the indicator is showing processing/retrying, defer or drop the notice —
   say which in the design doc. Never call `items()` from inside `onFailure`.
3. **Seed the Active Item from the clipboard present at launch** — *decision at GATE A, the supervisor brings
   Daniel's answer*. Recommended shape: `CopyCapture.init` takes the clipboard's current `snapshot()`; if it
   carries text and no concealed marker, it becomes the Active Item **and is recorded** in history (a pre-launch
   copy is still a copy); concealed → Active Item but not recorded (as today for live copies). No port change:
   `Clipboard.snapshot()` already exists. Unit-test with the fake clipboard in `FakeSystemPorts.swift`.
   Whether a `ClipboardSnapshot` yields a `ClipboardItem` today — check `ClipboardItem.swift`/`SystemClipboard`;
   if a small Core helper is needed, propose it at GATE A.
4. Own pasteboard writes stay invisible (already in Core — do not change; add no history entries for them).
5. **Do not build the history UI** (its own slice). No menu items, no lists.

### Tests
- Core: seeding (text / concealed / no text / empty) over the fake clipboard + `FakeHistoryRepository`.
- Shell (`Tests/JevPasteAppTests`): the history-failure notice mapping and its interaction with the presenter's
  states over the fake surface + manual clock; the fallback repository; the failure → main-actor hop
  (deterministic part only).
- Not unit-tested: the real file at `~/Library/Application Support/jevpaste/history.sqlite` — proven live.

## Steps
1. `docs/design/capture-and-history.md` (≤ 80 lines): composition, failure paths (init / runtime) and their
   visible form, the seeding rule you implement, threading (queue → main actor), what is unit-tested vs live-proven,
   and the live-run plan. **GATE A**: ask with the path and the seeding question restated in one line.
2. Implement TDD.
3. Live run — **ask first** (the installed app is shared with the other worker): `make install`, launch. Daniel
   copies two synthetic lines (you propose them), quits the app from the menu, relaunches; you read
   `~/Library/Application Support/jevpaste/history.sqlite` with `sqlite3` (or a tiny `--history-dump` probe if
   `--probe` is the established pattern — ask) and show the trimmed texts, newest first. Then the seeding proof:
   copy a synthetic line **before** launch, launch, ⌘⇧V into a matching Chrome `data:` textarea → inserted.
   Quit the app when done.

## Final steps
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files,
  and the proof evidence above.
- Post a report comment on issue #25: what was built, test count, proof evidence, deviations, open questions.
  **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`[capture] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
