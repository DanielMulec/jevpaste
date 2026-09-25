# Brief — Implement Free-text Target via Jev's third question (issue #41)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/free-text-target`, branch `free-text-target` (forked from `main`). This is a
**production slice**: TDD, review chain, merged when done. Your supervisor is the Pi session with intercom id
**`01a0d9a8`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly that id; ignore any other
pi in that cwd. Daniel (owner) speaks **only through the supervisor** — every live step where Daniel acts is an
`intercom ask`, and you wait. **A parallel worker exists** (`enter-after-no-match`, ticket #42); the installed
app is shared — `make install` only when a gate reply says go. See "Shared files" below.

Communication protocol:
- `intercom send 01a0d9a8` one line after every numbered step: `[free-text] step N done — <fact>`.
- `intercom ask 01a0d9a8` (blocking) at each **GATE** and for every live action; prefix with `[free-text]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. Never log or print item
  text or window titles; refer only to `JEVPASTE-…` synthetic payloads.

## Read first (in this order)
1. `gh issue view 41` — your ticket (assigned to Daniel; that is the claim, leave it).
2. The decision, verbatim: `gh api repos/DanielMulec/jevpaste/issues/comments/5821465655 -q .body`
   (resolution of [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35)).
3. The spike facts: `gh api repos/DanielMulec/jevpaste/issues/comments/5821700475 -q .body` and the primary
   source `git show ae72c56:spikes/free-text/FINDINGS.md` — the **`free_text` wording goes into the request
   verbatim** (instructions + both criteria strings). Threshold 0.8. App name + window title are sent.
4. `CONTEXT.md` (**Free-text Target**, **Direct Paste** — three doorways — and **Target Context** are the
   contract), `gh issue view 1` **Notes** (hard rules: 400 lines/file incl. tests; no payloads in logs; refer to
   issues by title), `docs/quality-gate.md`, `docs/design/jev-gateway.md`, `docs/design/direct-paste.md`,
   `docs/design/paste-attempt-state-machine.md`, `docs/design/pre-checks.md` (Target Context screening),
   `README.md` (privacy section), `Makefile`.
5. Code you will touch:
   - `Sources/JevGateway/EvaluateRequestBody.swift`, `EvaluateResponse.swift`, `JevGatewayDecisionService.swift`
     — third boolean question `free_text` in the same call; parse its probability.
   - `Sources/SmartPasteCore/Values/Decision.swift` — `Decision` gains the free-text probability.
   - `Sources/SmartPasteCore/Values/BoundTarget.swift` — `TargetContext` gains `appName: String?` and
     `windowTitle: String?` (bundle id is **not** sent). Screening: `Sources/SmartPasteCore/PreChecks/` /
     wherever `ScreenedTargetContext` is built — the window title passes the same secret rules as surrounding
     text; a hit withholds the title and the outcome note says so (extend `PasteAttemptNote`, keep one note
     type; propose the shape at GATE A).
   - `Sources/MacInterop/TargetContextReader.swift` (+ `AccessibilityTargetResolver.swift` if needed) —
     `NSWorkspace.shared.frontmostApplication?.localizedName`, focused window `AXTitle` via the focused element's
     `AXWindow`. Bounded like the other context reads.
   - `Sources/SmartPasteCore/PasteAttempt/PasteAttemptCoordinator+Decision.swift` `decided(_:)` — **your guard is
     the first statement of that function**: probability ≥ `freeTextThreshold` (named constant, 0.8) → deliver the
     whole Active Item as a Direct Paste (`DirectPasteRule`'s text transformation — outer line breaks stripped;
     reuse the existing function, do not re-implement), chooser never opens, free-text wins over a chosen
     excerpt. Below → the existing flow unchanged. **Do not touch the `noSuitableMatch` branch** (the parallel
     worker changes it).
   - `Sources/SmartPasteCore/Values/SmartPastePath.swift` — add `.freeTextTarget`; `RunningAttempt.path` in
     `PasteAttemptPhase.swift` must report it (the path is decided after Jev replies — propose how at GATE A;
     smallest change wins).
   - `Sources/JevPasteApp/Indicator/IndicatorPresenter.swift` `outcomeLogLine` — already prints `via=<path>`;
     add `p=0.93` (two decimals) on every Jev-consulted attempt: `via=freeTextTarget p=0.93` / `via=jev p=0.12`.
     Numbers and enums only. Direct Paste (single line) attempts print no `p=`.
   - `Tests/SmartPasteCoreTests/`, `Tests/JevGatewayTests/`, `Tests/MacInteropTests/` as they exist.
6. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
7. Tools for the live proof: the Chrome DevTools MCP server `chrome-devtools` (lazy: `mcp({connect:"chrome-devtools"})`
   first; `new_page`, `click`, `fill`, `evaluate_script`, `close_page` — re-list and verify the title before
   closing anything; it drives Daniel's real Chrome). Herdr CLI for terminal steps (`herdr tab create`,
   `herdr pane get <id>` focused=true + frontmost-app check before every synthetic step, `herdr pane send-keys
   <pane> C-c`, `herdr pane read <pane> --source visible`). The installed app started with
   `--accept-signal-trigger` accepts `kill -USR1 <pid>` as ⌘⇧V (see `Sources/JevPasteApp/Launch/AcceptanceTrigger.swift`).
8. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Scope
1. **Gateway**: third boolean question with the spike wording verbatim; response parsing; `Decision` carries
   `freeTextProbability`. Existing two questions and id mapping untouched. Tests via the transport seam.
2. **Target Context**: `appName` + `windowTitle` read in MacInterop and sent under `app_name` / `window_title`
   (absent keys omitted, as the spike did). Window title screened like surrounding text; withheld title noted
   on the outcome. Tests for the screening and for the request body.
3. **Core rule**: `freeTextThreshold = 0.8` named constant; `decided(_:)` first guard as above. Tests: at 0.8 →
   whole item delivered, no chooser even with same-type alternatives, no `accepts` check on candidates
   needed (the text is the whole item — say at GATE A how `PasteResultValidation` treats it); at 0.79 → old
   flow; a multi-line item; the labelled-field case with p=0.05 still delivers the excerpt only; pre-checks still
   refuse first; single-line items never reach Jev (regression).
4. **Log line** as above, per attempt.
5. **Docs**: `docs/design/jev-gateway.md` (third question, wording, cost), `docs/design/direct-paste.md`
   (third doorway), state-machine doc where the branch sits, README privacy note: app name + window title now
   leave the Mac (what is *not* sent: bundle id, contents of other windows). `CONTEXT.md` only if the
   implementation proves a wording wrong (say so).

Out of scope: the Enter-after-No-Suitable-Match offer (#42), the cold-AX wake question (#36), any local
unlabelled-target rule, per-app lists, changes to the single-line rule or the pre-check rules.

## Shared files with the parallel worker `enter-after-no-match` (#42)
- `PasteAttemptCoordinator+Decision.swift` `decided(_:)`: you own the **first guard**; #42 owns the
  `finish(.noSuitableMatch)` line. Touch nothing else in that function.
- `SmartPastePath.swift`: you add `.freeTextTarget`; #42 may add a reason for its path — additive on both sides.
- `PasteAttemptPhase.swift`: #42 adds a phase; you may change `RunningAttempt.path` only.
- `IndicatorPresenter.swift`: you change **only** `outcomeLogLine`; #42 owns the rest of the file and
  `OutcomeMessage.swift` / `IndicatorPanel.swift` — do not touch those.
- `PasteAttemptOutcome.swift`: do not touch. Tests: add **new** test files rather than editing
  `PasteAttempt*Tests` heavily; name them `FreeTextTarget…Tests.swift`.
- The supervisor merges whichever branch is ready first and asks the other to rebase; expect one rebase.

## Steps
1. `docs/design/free-text-target.md` (≤ 70 lines): the third question (wording verbatim), the threshold and
   where it lives, how the path is reported (`RunningAttempt.path`), the screening + note shape for the window
   title, the request-body shape with the two new keys, the test list, and the **live-run plan** in plain words
   (what is opened, what is pressed, what is looked at, *why* each step exists). **GATE A**: ask with the doc
   path and the three proposals (path reporting, note shape, validation of the whole-item text).
2. Implement TDD, small commits (`make check` green before each). Push after each gate.
3. **GATE B**: ask with the `make test` summary line, `wc -l` of your files, and a one-line proof per scope
   item (test names). The supervisor reads the Core + Gateway diff before approving.
4. Live proof (gated; ask once for `make install`, then run the automated part, then ask once for Daniel's
   block — expect to wait for the other worker's turn). Synthetic multi-line payload only, e.g. three lines
   `JEVPASTE-FT-NAME Marlene Example` / `ft41@example.org` / `+41 79 555 01 23` (pure values per line).
   Automated (you, no Daniel): (a) a Chrome `data:` page with a bare `<textarea>` and nothing else → whole
   item landed, `via=freeTextTarget p=…`; (b) a Chrome `data:` page with a labelled *Email address* input →
   **only the email excerpt**, `via=jev p=…` low; (c) a Herdr shell prompt → whole item at the prompt, not
   executed, then `C-c`. Daniel's block (one `ask`, all steps in plain words): (d) the ChatGPT desktop app
   composer (bundle `com.openai.codex` **is** ChatGPT; "Waking ChatGPT…" means press again) → whole item
   landed, not sent; (e) WhatsApp composer → whole item landed, not sent. Record log lines (`log show … --info`,
   no payloads, `p=` values included). Every helper output that backs a claim goes into the run log.
5. Push. Post a report comment on issue #41: what was built, the wording, test count, live evidence with `p=`
   values per target, commits, merge touchpoints (files the composition root and shared files changed), open
   questions. **GATE C**: ask with the comment URL, then end your turn. Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Descriptive names from the glossary. No new dependencies without `ask`. Commit small on `free-text-target`.
  Bare `swift test` does not link — use `make test`. Do not merge.

## Report format
`[free-text] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
