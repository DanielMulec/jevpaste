# Brief — Implement Direct Paste for single-line items (issue #34)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/direct-paste`, branch `direct-paste` (forked from `main`). This is a **production
slice**: TDD, review chain, merged when done. Your supervisor is the Pi session with intercom id **`01a0d1b6`**
(cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly that id; ignore any other pi in that cwd.
Daniel (owner) speaks **only through the supervisor** — every live step where Daniel acts is an `intercom ask`,
and you wait. **A parallel worker exists** (`history-ui`); the installed app is shared — `make install` only
when a gate reply says go.

Communication protocol:
- `intercom send 01a0d1b6` one line after every numbered step: `[direct-paste] step N done — <fact>`.
- `intercom ask 01a0d1b6` (blocking) at each **GATE** and for every live action; prefix with `[direct-paste]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. Never log or print item
  text; refer only to `JEVPASTE-…` synthetic payloads.

## Read first (in this order)
1. `gh issue view 34` — your ticket (the supervisor assigns it to Daniel; that is the claim, leave it).
2. The decision you implement, verbatim: the resolution comment of
   [Skip Jev for a single line, and skip Jev when there is nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/32)
   (`gh issue view 32 --comments`, last comment). **Rule 2 in that comment is deferred — do not build it.**
3. `CONTEXT.md` (**Direct Paste** and the updated **Smart Paste** entries are the contract), `gh issue view 1`
   **Notes** (hard rules: 400 lines/file incl. tests; no payloads in diagnostic logs; refer to issues by title),
   `gh issue view 16 --comments` (slice plan + acceptance rules), `docs/quality-gate.md`,
   `docs/design/paste-attempt-state-machine.md`, `Makefile`.
4. Code you will touch: `Sources/SmartPasteCore/PasteAttempt/PasteAttemptCoordinator.swift` (`hotkeyPressed`
   — the branch goes **after the pre-check** and **before** Candidate derivation),
   `PasteAttemptCoordinator+Delivery.swift` (`deliver(_:)` takes a `Candidate`; a Direct Paste reuses the same
   write → ⌘V keystroke → restore path and the same Bound Target re-verification),
   `Sources/SmartPasteCore/Values/PasteAttemptOutcome.swift`, `Sources/JevPasteApp/Indicator/OutcomeMessage.swift`
   (feedback stays the plain ✓ — likely untouched), the `PasteAttempt` log lines (`outcome inserted` must name
   the path), `Tests/SmartPasteCoreTests/PasteAttempt*`.
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Scope
1. **Single-line rule** as a named Core value (e.g. `DirectPasteRule` — you name it from the glossary):
   the Active Item, ignoring leading/trailing whitespace and line breaks, contains no line break (`\n`, `\r\n`,
   `\r`). `"  x@y.org\n"` → single line; `"a\n\nb"` → not. Pinned by parameterised tests incl. CRLF, lone CR,
   trailing blank lines, whitespace-only (already refused by pre-checks — assert the order).
2. **Direct Paste text**: the item verbatim, **trailing line breaks stripped**, nothing else changed (leading
   whitespace and inner whitespace kept byte-for-byte). Test it.
3. **Coordinator branch**: after `preCheck.refusal` and before `candidateExtraction`: single line → deliver the
   Direct Paste text through the existing delivery path (Bound Target re-verified, clipboard write, keystroke,
   Restore Window, `insertedWithoutRestore` on a foreign copy) with **no Jev call, no Candidates, no chooser, no
   processing indicator, no 5 s deadline** (delivery has its own bound). Tests: no `decisionService` call;
   the paste is the Direct Paste text; a Rejev-paste of an older single-line item Direct Pastes; a multi-line
   item still goes through Jev (regression); the labelled-field case pastes anyway (no type check).
4. **Outcome and log**: the visible outcome stays `✓` — same `inserted` / `insertedWithoutRestore`. The
   `PasteAttempt` log line names the path (e.g. `outcome inserted via=directPaste` vs `via=jev`), ints/enums only.
   Decide at GATE A whether the path rides on the outcome value or on the log call only; prefer the smallest
   type change that keeps `OutcomeMessage` untouched.
5. **Docs**: `docs/design/direct-paste.md` (≤ 50 lines) and the state-machine doc updated where the new branch
   sits; `CONTEXT.md` is already updated — only fix it if the implementation proves a wording wrong (say so).

Out of scope: Rule 2 (nothing to reason about), any context-shape logging, dropping the pre-checks, the history
UI, Candidate derivation, Jev semantics.

## Steps
1. `docs/design/direct-paste.md`: the rule, the text transformation, where the branch sits (3 lines of the
   state machine), the outcome/log choice (item 4), test list, and the live-run script for Daniel in plain
   words — what to click, what to look at, *why* each step exists. **GATE A**: ask with the doc path and the
   item-4 choice.
2. Implement TDD, small commits (`make check` green before each).
3. **GATE B**: ask with the `make test` summary line, `wc -l` of your files, and a one-line proof per scope
   item (test names). The supervisor reads the Core diff before approving.
4. Live proof (gated, one `ask` for install, then one `ask` for the block — expect to wait for the other
   worker's turn): single-line synthetic item (`printf 'JEVPASTE-DP-ONE@example.org' | pbcopy`, no trailing
   newline; and a second run with `printf 'JEVPASTE-DP-TWO@example.org\n'` to prove the stripped newline):
   (a) Chrome labelled *Email address* field → ✓, text landed, log `via=directPaste`, no `JevGateway` line;
   (b) a Herdr shell prompt → text at the prompt, **not executed**, ✓; then Ctrl-C;
   (c) the ChatGPT desktop app composer (bundle `com.openai.codex` — that **is** ChatGPT, do not question it;
   first press after a cold start may say "Waking ChatGPT…", press again) → text landed, message **not** sent;
   (d) a two-line item → "Jev is choosing…" then the ordinary Jev outcome (regression).
   Record log lines (no payloads).
5. Push. Post a report comment on issue #34: what was built, rule, test count, live evidence, commits, merge
   touchpoints, open questions. **GATE C**: ask with the comment URL, then end your turn. Do not merge, do not
   close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Descriptive names from the glossary. No new dependencies without `ask`. Commit small on `direct-paste`; push
  after each gate. Do not merge.
- **Shared files** with the parallel `history-ui` worker: it edits `Sources/SmartPasteCore/Capture/CopyCapture.swift`,
  `Sources/JevPasteApp/StatusItemPanelParts.swift`, `MenuBarDelegate`, `SmartPasteApplication.swift` and adds
  `Sources/JevPasteApp/HistoryPanel/*`. Do not touch those; if you must, `ask`.

## Report format
`[direct-paste] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
