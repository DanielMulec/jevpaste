# Handoff — capture-history (issue #25: Add clipboard capture and persistent history)

Worktree `~/.pi/worktrees/jevpaste/capture-history`, branch `capture-history`, forked from `main` 0ef117e.
Head before this handoff: `d49d87b`; ticket [Add clipboard capture and persistent history](https://github.com/DanielMulec/jevpaste/issues/25) (pushed, **not merged**). `make check` green: 249 tests in 47 suites.
Report: https://github.com/DanielMulec/jevpaste/issues/25#issuecomment-5789267575 · Design:
`docs/design/capture-and-history.md` · Brief: `docs/briefs/capture-history-brief.md` · Review:
`~/.pi/worktrees/jevpaste/review-capture/REVIEW-BRIEF.md` (GPT-6-Sol, verdict fix → fixed in d49d87b).

## 1. Commits
| sha | what |
|---|---|
| [eac99e6](https://github.com/DanielMulec/jevpaste/commit/eac99e6) | design doc (GATE A approved) |
| [e22601e](https://github.com/DanielMulec/jevpaste/commit/e22601e) | Core `CopyCapture` Launch Adoption + `SystemClipboard.currentItem()`; `ScratchPasteboard.copyLikeAnotherApp` extracted from `ClipboardObservationTests` |
| [50910b2](https://github.com/DanielMulec/jevpaste/commit/50910b2) | `HistoryNotice` (failure → text/duration) + `HistoryNoticeSurface` decorator; `JevPasteAppTests` depends on `HistoryStore` |
| [0071eaa](https://github.com/DanielMulec/jevpaste/commit/0071eaa) | `ClipboardHistoryOpening`, `UnavailableHistoryRepository` (renamed/moved interim), composition root, `app-shell.md` rows |
| [d49d87b](https://github.com/DanielMulec/jevpaste/commit/d49d87b) | review fixes: launch contents read after observation starts (closure), fake clipboard baselines; stale presenter `hide()` ignored |

## 2. Architecture (all in `Sources/JevPasteApp` unless stated)
- **Launch Adoption** (formerly "seeding"; renamed on Daniel's request — the synthetic test row is a *fixture*) — Core `CopyCapture.init(clipboard:history:contentsAtLaunch: @MainActor () -> ClipboardItem? = { nil })`.
  It calls `startObservingChanges` **first**, then the closure, then `adopt(_:)` (the shared live-copy path: Active
  Item; `record` unless concealed). Why a closure of a `ClipboardItem`, not a `ClipboardSnapshot`: the snapshot is
  opaque to Core and the concealed-marker check (MacInterop, must precede content reads per #6) lives in the
  adapter. `SystemClipboard.currentItem()` (MacInterop) is public on the adapter only, **not** on the `Clipboard`
  port. Root passes `{ clipboard.currentItem() }`. Why after subscribing: `SystemClipboard` baselines
  `lastObservedCount` at subscription; reading first lost a copy landing in between. A copy between baseline and
  read is adopted at launch and reported once more by the poll → recorded twice, deduped by history (move-to-top).
- **`History/ClipboardHistoryOpening`** (`@MainActor enum`): `open(at: = defaultFileURL, notices:)` tries
  `SQLiteHistoryRepository(fileURL:retentionLimit: 500, onFailure:)`; on throw logs the kind (`jevpaste`/`History`),
  shows `HistoryNotice(unavailable:)` at once and returns `UnavailableHistoryRepository()`. `reportingFailures(to:)`
  is `nonisolated`, returns the `@Sendable` callback that only does `Task { @MainActor in deliver(notice) }` —
  never touches the repository (it runs on the repository's serial queue; `items()` there would deadlock).
- **`History/UnavailableHistoryRepository`**: keeps nothing; Smart Paste keeps working on the Active Item.
- **`History/HistoryNotice`**: "History unavailable — <reason>" 5 s (reasons per `HistoryStoreFailure`, result 26 =
  not a database, operation `open` = could not be opened); runtime: operation `items` → "History read failed",
  anything else → "History write failed", 2.5 s. Symbol `exclamationmark.triangle`.
- **`Indicator/HistoryNoticeSurface`** — an `IndicatorSurface` decorator between `IndicatorPresenter` and the panel.
  Contract: presenter `display` always passes through, marks the presenter busy and cancels a notice's hide timer;
  presenter `hide()` ends busy and shows the newest waiting notice (else hides); a `hide()` while not busy is stale
  and ignored; `show(notice)` displays at once when not busy (own hide timer), else waits (newest only — older ones
  were logged). Clicks forward unchanged. Why a decorator: the presenter files belong to the parallel chooser
  slice; the presenter stays sole owner of attempt states; notices are deferred, never dropped (a failed write in
  the Restore Window stays visible).
- Composition root diff: `notices = HistoryNoticeSurface(wrapping: panel, clock:)`, presenter's `surface: notices`,
  the `CopyCapture(...)` call. Core ports unchanged.

## 3. Review findings
- BLOCKING launch race (launch contents read before subscription) → fixed d49d87b. Tests `copyJustBeforeObservationStarts…`
  (later item Active, recorded once) and `copyBetweenStartingObservationAndReadingTheSeed…` (recorded twice =
  upsert); both proven red with the old order. `FakeClipboard.startObservingChanges` now drops earlier changes
  like the adapter and has `foreignCopyJustBeforeObservationStarts`.
- NON-BLOCKING stale presenter `hide()` → fixed d49d87b (`aStalePresenterHideLeavesAShowingNoticeForItsFullDuration`).
- NON-BLOCKING init-failure log lacks the file name → declined by supervisor (HistoryStore already logs it).

## 4. Merge touchpoints with `candidate-chooser` (checked against origin/candidate-chooser d10a878)
- `SmartPasteApplication.swift`: the chooser branch replaces `let panel = IndicatorPanel { … }` with a
  `statusItemFrame` closure + `IndicatorPanel(anchorFrame: statusItemFrame)` and changes the `chooser:` argument
  to `PanelCandidateChooser(…, indicator: presenter)`. Textual conflict around the panel/presenter lines.
  Resolve: keep chooser's `statusItemFrame` + panel lines, then this branch's `notices` line,
  `IndicatorPresenter(surface: notices, clock: clock)`, and the `CopyCapture(... contentsAtLaunch: { clipboard.currentItem() })`
  call; keep chooser's `chooser:` block. Also drop their `DiscardingHistoryRepository()` (type no longer exists).
- **Semantic conflict — `IndicatorPresenter.hideWhileChoosing()`** calls `hide()` → `surface.hide()` → through
  this decorator, which then treats the presenter as idle: a waiting notice appears **while the chooser is open**,
  and a new failure notice during choosing shows at once. Two panels under the status item; untested today.
  Recommendation (needs a small presenter edit at merge time, ask first): add `IndicatorSurface.hideWhileBusy()`
  (protocol extension default = `hide()`); `hideWhileChoosing` calls it; `HistoryNoticeSurface` overrides it to
  hide the panel but stay busy, so notices wait until the outcome's display + hide. Add one test in
  `HistoryNoticeSurfaceTests`: notice during choosing waits until the outcome hides. Cheaper alternative: accept
  it and document (notices are rare).
- `docs/design/app-shell.md` shell-adapter table: this branch replaced the `DiscardingHistoryRepository` row with
  `UnavailableHistoryRepository`; chooser replaced the `UnbuiltCandidateChooser` row on the next line. Keep both
  new rows. This branch also edited the "Active Item = …" bullet and the open-questions line.
- `IndicatorPresenterTests`/`OutcomeMessageTests` are chooser-edited; this branch did not touch them.

## 5. Open questions / live-proof gaps
- Live (a): after two synthetic copies + quit + relaunch, `sqlite3` read them back newest first — proven.
- Live (b): Launch Adoption of the pre-launch copy → **proven on merged main f610b8b** (Daniel copied one email
  before launch, ⌘⇧V → `outcome inserted`, email confirmed in the textarea).
- Launch Adoption (launch clipboard becomes the Active Item and is recorded) — **confirmed by Daniel**; keep as is.
- "History read failed" is unreachable until the History UI calls `items()`.
- `sqlite3`'s `trim()` strips spaces only — compare with `LIKE`, not `trim()`, when checking multi-line rows.

## 6. Do not
- Merge, or `make install`/launch the shared `~/Applications/JevPaste.app` without a supervisor "go".
- Call `items()` or any repository method from `onFailure`; change Core ports; add `currentItem` to `Clipboard`.
- Print or store Daniel's real clipboard or history rows (read only `JEVPASTE-…` synthetic rows); print
  `~/.config/jevpaste/env`.
- Edit chooser-owned files (`IndicatorPresenter`, `OutcomeMessage`, `IndicatorPanel`, `Chooser/`) on this branch
  without asking. Keep files ≤ 400 lines; `make check` before every commit.

## Suggested skills
- `~/.agents/skills/tdd/SKILL.md` — every fix here goes red→green (prove new tests red against the old code, as in d49d87b).
- `~/.agents/skills/codebase-design/SKILL.md` — for the `hideWhileBusy` seam decision (§4): keep the presenter the owner of attempt states.
- `~/.agents/skills/resolving-merge-conflicts/SKILL.md` — for the `SmartPasteApplication.swift` / `app-shell.md` conflicts with `candidate-chooser`.
- `pi-intercom` skill — supervisor `01a0cc6f`: `send` after each step, `ask` at gates and before any `make install`.
- `~/.agents/skills/code-review/SKILL.md` — to self-check `git diff main...capture-history` against the brief before a new review pass.
