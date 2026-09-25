# Brief — Implement the Wake Wait (issue #43)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/wake-wait`, branch `wake-wait` (forked from `main`). This is a **production
slice**: TDD, review chain, merged when done. Your supervisor is the Pi session with intercom id
**`01a0da0a`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly that id; ignore any other
pi in that cwd. Daniel (owner) speaks **only through the supervisor** — every live step where Daniel acts is an
`intercom ask`, and you wait. You are the only worker; the installed app is still shared with Daniel's daily
use — `make install` only when a gate reply says go.

Communication protocol:
- `intercom send 01a0da0a` one line after every numbered step: `[wake-wait] step N done — <fact>`.
- `intercom ask 01a0da0a` (blocking) at each **GATE** and for every live action; prefix with `[wake-wait]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. Never log or print item
  text or window titles; refer only to `JEVPASTE-…` synthetic payloads.

## Read first (in this order)
1. `gh issue view 43` — your ticket (assigned to Daniel; that is the claim, leave it). Its bullets are scope.
2. The decision, verbatim — the **ten settled points are the contract**:
   `gh api repos/DanielMulec/jevpaste/issues/comments/5838246196 -q .body`
   (resolution of [Don't wake the target app for a Direct Paste](https://github.com/DanielMulec/jevpaste/issues/36)).
3. `CONTEXT.md` (**Wake Wait**, **Bound Target**, **Pre-check**, **Direct Paste**), `gh issue view 1` **Notes**
   (hard rules: 400 lines/file incl. tests; no payloads in logs; refer to issues by title), `docs/quality-gate.md`,
   `docs/design/paste-attempt-state-machine.md`, `docs/design/chatgpt-resolver.md` (the wake logic you replace),
   `docs/design/mac-interop.md`, `docs/design/direct-paste.md`, `docs/design/no-suitable-match-offer.md`
   (how `KeyPanelSession` and the indicator's offer state were added — the pattern for a new phase), `Makefile`.
4. Evidence of the two cases you fix: `docs/acceptance/run-2026-09-25-free-text.log` (ChatGPT
   `refused.targetWaking` on the first press) and `docs/acceptance/run-2026-09-25-enter-after-no-match.log`
   (fresh Chrome tab `refused.noEditableTarget` on the first press).
5. Code you will touch:
   - `Sources/SmartPasteCore/Seams/TargetResolver.swift` — `TargetResolution.waking` becomes "focus unreadable"
     (rename from the glossary; it no longer implies a wake was *requested*).
   - `Sources/MacInterop/FocusedTargetResolver.swift` — `resolutionWhileFocusIsUnreadable()`, the 5 s per-pid
     `wakeWindow`; `Sources/MacInterop/AXFocusSource.swift` — `wakeFrontmostAppAndRetry` (300-node walk),
     `isAccessibilityAwake` / `wakeAccessibility` (`AXEnhancedUserInterface`). **Any** frontmost app with an
     unreadable focus reports unreadable; the wake request (Electron switch) stays a one-shot side effect.
   - `Sources/SmartPasteCore/PasteAttempt/PasteAttemptCoordinator.swift` `hotkeyPressed()` — the wait goes
     into the `switch ports.targetResolver.resolveFocusedTarget()`, **before** `rules.preCheck` and before
     `DirectPasteRule`; re-resolve on `ports.clock` (the Core clock — see how `attemptTimeLimit` and the 429
     retry schedule use it) until resolved or `wakeWaitLimit = 3 s` (named constant). The 5 s Jev clock starts
     only when the Bound Target is resolved (today: `deadline: ports.clock.now + Self.attemptTimeLimit` in
     `askJev`). Poll interval is your Gate A proposal.
   - `PasteAttemptPhase.swift` — new phase (name from the glossary, e.g. `.wakeWaiting`); `hotkeyPressed`'s
     `guard phase == .idle` stays (a second ⌘⇧V during the wait is ignored like any running attempt — say so
     at Gate A if you think it should cancel instead).
   - `Sources/SmartPasteCore/Values/PasteAttemptOutcome.swift` — `PreCheckRefusal.targetWaking` → rename to
     what it now means (the limit passed; keep the app name).
   - `Sources/JevPasteApp/Indicator/OutcomeMessage.swift` — "Waking … — press ⌘⇧V again in a moment" goes
     away; new text exactly `<App> isn't ready — press ⌘⇧V again`; log key for the refusal.
   - `Sources/SmartPasteCore/Seams/PasteOutcomePresenter.swift` + `Sources/JevPasteApp/Indicator/IndicatorPresenter.swift`
     — the indicator during the wait: reuse the processing indicator mechanism (150 ms rule, click cancels →
     `.cancelled`, nothing pasted) with the label `Waking <App>…`. Smallest seam change wins (e.g.
     `showProcessing` gains a label/kind, or a `showWaking(applicationName:onCancel:)`) — propose at Gate A.
     Esc: the processing indicator does not take key focus, so "Esc cancels" means the same as today for
     processing (click) unless you find a cheap way to honour Esc via `KeyPanelSession` — propose, don't gold-plate.
   - `IndicatorPresenter.outcomeLogLine` — add `wakeWait=<ms>` on attempts that waited (integer ms); attempts
     that did not wait print nothing. Enums and numbers only.
   - `Tests/SmartPasteCoreTests/`, `Tests/MacInteropTests/`, `Tests/JevPasteAppTests/` as they exist; the
     `FakeTargetResolver` (or equivalent) must be able to answer "unreadable" N times then "resolved".
6. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
7. Tools for Gate A and the live proof: Chrome DevTools MCP server `chrome-devtools` (lazy:
   `mcp({connect:"chrome-devtools"})` first; `list_pages`, `new_page`, `select_page`, `click`, `fill`,
   `evaluate_script`, `close_page` — **re-list and verify the title immediately before closing anything**; it
   drives Daniel's real Chrome, and `hasFocus()` is emulated — gate every synthetic step on the frontmost app
   being Chrome). Herdr CLI for terminal steps (`herdr tab create`, `herdr pane get <id>` focused=true +
   frontmost-app check before every synthetic step, `herdr pane send-keys <pane> C-c`, `herdr pane read <pane>
   --source visible`). The installed app started with `open ~/Applications/JevPaste.app --args
   --accept-signal-trigger` accepts `kill -USR1 <pid>` as ⌘⇧V (`Sources/JevPasteApp/Launch/AcceptanceTrigger.swift`).
   Launch the app via `open … --args`, never from your shell (a shell-launched binary has no Accessibility).
   Read logs with `log show --predicate 'subsystem == "jevpaste"' --info --last 2m` (adjust; see existing
   acceptance logs for the exact predicate).
8. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Scope
1. **Gate A measurement (first, before design):** a fresh Chrome `data:` tab with a bare `<textarea>` — the
   case that refused `noEditableTarget` on 2026-09-25. Question: does *re-reading the focus alone* resolve it
   within 3 s, or does Chrome need `AXEnhancedUserInterface` too? Measure with a small throwaway probe
   (a script or a test-scaffold branch of `AXFocusSource` — keep it out of the production diff or behind the
   existing acceptance-trigger scaffolding) against the **installed** app or a `swift run` probe that has the
   Accessibility grant (ask if you cannot get one). Record: time-to-readable in ms across ≥ 3 fresh tabs, with
   and without the switch. Implement the **minimum that passes**; numbers go into the design doc.
2. **Resolver**: unreadable focus in any frontmost app → unreadable (never `noEditableTarget`); `noEditableTarget`
   only for a readable focus with nothing editable; the one-shot Electron wake request stays; the 5 s per-pid
   window is removed or folded into the wait (your call at Gate A, with reason). Tests through `FocusSource`.
3. **Core Wake Wait**: new phase; re-resolve on the clock; `wakeWaitLimit = 3 s`; cancel → `.cancelled`; limit
   → the renamed refusal with the app name; on resolve → the unchanged flow (Pre-checks → Direct Paste /
   Free-text / Jev) with the 5 s clock starting *then*. Tests: resolves on the 2nd poll → attempt proceeds and
   the Jev deadline is `now + 5 s` at that moment; never resolves → refusal at 3 s, no Jev call; cancel mid-wait
   → cancelled, no Jev call, no paste; readable at once → no wait, no indicator (regression); pre-check refusal
   still fires after a wait; single-line Direct Paste after a wait; the outcome carries the waited duration.
4. **Indicator + wording**: `Waking <App>…` after 150 ms via the reused mechanism; click cancels; refusal text
   exactly as above; `OutcomeMessage` wording tests updated; log key for the refusal.
5. **Log line**: `wakeWait=<ms>` as above.
6. **Docs**: `docs/design/wake-wait.md` (≤ 70 lines: the phase, poll interval + why, the clock rule, the Gate A
   numbers, what became of the per-pid window, the indicator mechanism, the test list, the live-run plan in
   plain words), `paste-attempt-state-machine.md` (new phase, where the 5 s clock now starts),
   `chatgpt-resolver.md` (mark superseded or fold), `CONTEXT.md` only if the implementation proves a wording
   wrong (say so).

Out of scope: blind paste, per-app lists, changes to Pre-check rules, the chooser, history, Free-text or the
Enter offer, any new UI beyond the reused indicator.

## Steps
1. **Gate A measurement** (scope 1) — you may need `make install` of an instrumented build; ask first. Report
   the numbers in one `send`.
2. `docs/design/wake-wait.md`. **GATE A**: ask with the doc path and your proposals: poll interval, phase name,
   the resolver enum rename, the presenter seam change, the fate of the per-pid window, Esc handling, and
   whether the Gate A numbers require the Chrome switch.
3. Implement TDD, small commits (`make check` green before each). Push after each gate.
4. **GATE B**: ask with the `make test` summary line, `wc -l` of every file you touched, and a one-line proof
   per scope item (test names). The supervisor reads the Core + MacInterop + Indicator diff before approving.
5. Live proof (gated; ask once for `make install`, then run the automated part, then ask once for Daniel's
   block). Payloads: single line `wake43@example.org` (Direct Paste path — pure value) and a three-line item
   `JEVPASTE-WW-NAME Marlene Example` / `ww43@example.org` / `+41 79 555 01 43` for the Jev path.
   Automated (you, no Daniel): (a) **fresh Chrome `data:` tab** with a bare `<textarea>`, focus it, fire
   SIGUSR1 immediately → one press pastes, log shows `wakeWait=<ms>` (or 0 wait if Chrome is readable at
   once — then say so); repeat 3×; (b) a Herdr shell prompt → no wait, no `wakeWait=` key, value at the prompt,
   not executed, then `C-c` (regression); (c) the after-limit refusal — force it if feasible (e.g. a
   frontmost app whose tree stays unreadable; propose how at Gate A), else reasoned from tests and stated as
   such. Daniel's block (one `ask`, plain words, say *why* each step exists): (d) quit the ChatGPT desktop app
   (bundle `com.openai.codex` **is** ChatGPT), relaunch it, click the composer, press ⌘⇧V **once** → the value
   lands, no "press again"; tell him to move the mouse to the top edge to see the indicator, and that his menu
   bar auto-hides so the log is the proof. Record log lines (no payloads). Every helper output that backs a
   claim goes into the run log `docs/acceptance/run-<date>-wake-wait.log` at run time.
6. Push. Post a report comment on issue #43: what was built, Gate A numbers, wording, test count, live evidence
   with `wakeWait=` values per target, commits, merge touchpoints, open questions. **GATE C**: ask with the
   comment URL, then end your turn. Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Descriptive names from the glossary. No new dependencies without `ask`. Commit small on `wake-wait`.
  Bare `swift test` does not link — use `make test`. Do not merge.
- Reviewers read the committed log, not your session: every digest/count backing a claim goes into the log.

## Report format
`[wake-wait] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
