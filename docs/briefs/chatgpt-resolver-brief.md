# Brief — Restore Smart Paste in the ChatGPT desktop app (issue #33)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/chatgpt-resolver`, branch `chatgpt-resolver` (forked from `main`). Your supervisor
is the Pi session with intercom id **`01a0cff5`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id; ignore any other pi in that cwd. Daniel (owner) speaks **only through the supervisor**.
**Two parallel workers exist** (`pre-checks`, `history-probe`); the installed app `~/Applications/JevPaste.app`
and Daniel's attention are shared — every `make install` and every step where Daniel acts is an `intercom ask`,
and you wait.

Communication protocol:
- `intercom send 01a0cff5` one line after every numbered step: `[chatgpt] step N done — <fact>`.
- `intercom ask 01a0cff5` (blocking) at each **GATE** and before every live action; prefix with `[chatgpt]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. Never log or post
  field contents from Daniel's apps — counts, roles, attribute names and error codes only.

## Read first (in this order)
1. `gh issue view 33` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. `~/.agents/skills/diagnosing-bugs/SKILL.md` — this is a root-cause hunt; follow the loop. Then
   `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
3. The evidence: the multi-line probe report
   (`gh api repos/DanielMulec/jevpaste/issues/comments/5801268147 -q .body`, "Side findings" §1) and the
   probe code on branch `multiline-probe` (`git show multiline-probe --stat`; its per-bundle fallback is
   scaffolding — do **not** port it).
4. `Sources/MacInterop/` — `AXFocusSource.swift` (system-wide focused element + the 300-node Chromium wake
   walk), `FocusedTargetResolver.swift`, `AccessibilityTargetResolver.swift`, `AccessibilityNode.swift`,
   `AXElementNode.swift`; `Tests/MacInteropTests/`.
5. `gh issue view 11 --comments` — the earlier probe **did** resolve the ChatGPT app; its code lives in worktree
   `~/.pi/worktrees/jevpaste/macos-probe` (branch `spike/macos-probe`). Diff how it found the focused element
   against today's `AXFocusSource`.
6. `gh issue view 1` **Notes** (hard rules), `CONTEXT.md`, `docs/design/mac-interop.md`, `docs/signing.md`,
   `docs/quality-gate.md`, `Makefile`.
7. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Constraints you must know
- Your shell has **no Accessibility grant**: AX queries from a plain process return errors. Only the signed
  installed bundle (`make install`, identity `jevpaste-dev`) can read the AX tree or post events. Diagnostics
  therefore ride **inside the app**, at ⌘⇧V time, with Daniel pressing the hotkey in the ChatGPT app — gated.
- Daniel's ChatGPT app IS bundle `com.openai.codex`. Treat it as an ordinary Electron/Chromium app.
- The fix must be **app-agnostic**: no bundle ids, no per-app branches. If a mechanism only works when a
  specific app is targeted, it is not the fix.
- Core (`Sources/SmartPasteCore`) is not expected to change; if you believe it must, `ask` with the seam reasoning.

## Hypotheses to test (form your own; these are starting points, not answers)
- System-wide `AXFocusedUIElement` vs. the frontmost application element's own `AXFocusedUIElement`
  (and `AXFocusedWindow` → `AXFocusedUIElement`) — different sources, different answers on Chromium.
- Electron/Chromium apps expose a live tree only after an AX client sets `AXManualAccessibility` (Electron) or
  `AXEnhancedUserInterface` to `true` on the **application** element; Chrome itself wakes on a walk, Electron
  may not.
- Wake-walk size/timing: 300 nodes may end before the composer's subtree; a second query after a short delay
  may succeed where an immediate retry fails.
- App update since the #11 probe changed the tree.

## Steps
1. Read, diff against the #11 probe, write `docs/design/chatgpt-resolver.md` (≤ 60 lines): the observed
   failure, ranked hypotheses, the **diagnostic plan** (what the app will log at ⌘⇧V — attribute names,
   error codes, node counts/roles only), and how each hypothesis is confirmed or killed. **GATE A**: ask with
   the path and the ranked hypotheses in one line each.
2. Add the diagnostic (temporary, behind a log category or a `--diagnose-focus` flag — your call, say which),
   `make app`. **GATE B1**: ask for install permission and give the supervisor the exact instruction block
   for Daniel (open ChatGPT, click into the composer of a throwaway chat, press ⌘⇧V once, report the indicator
   text) plus the `log show` command you will run afterwards. Iterate — each further live round is its own
   `ask`, batched as tightly as you can.
3. With the root cause confirmed: TDD the fix in MacInterop (red test over the existing fakes first), remove or
   permanently justify the diagnostic, `make check` green. **GATE B2**: ask with the `swift test` summary line,
   `wc -l` of touched files, the root cause in two lines, and the fix in two lines; the supervisor reads the diff.
4. Live proof (gated, one `ask`): `make install`; Daniel presses ⌘⇧V in the ChatGPT composer with a synthetic
   Active Item the supervisor puts on the clipboard (`pbcopy`), and reports: text landed in the composer /
   message **not** sent / ✓ shown. Regression: one ⌘⇧V each in a Chrome `data:` textarea and a Herdr shell
   prompt (both still resolve). Record the log lines (counts/verdicts only).
5. Push the branch. Post a report comment on issue #33: root cause, fix, why it is app-agnostic, test count,
   live evidence, commits, merge touchpoints, open questions. **GATE C**: ask with the comment URL, then end
   your turn. Do not merge, do not close the issue.

## Rules
- TDD, Swift Testing, Swift 6 strict concurrency; `make check` green before every commit; ≤ 400 lines/file;
  glossary names; no new dependencies without `ask`. Commit small on `chatgpt-resolver`; push after each gate.
- Shared files with the parallel `pre-checks` worker: none expected (it works in Core + the shell composition
  root). If you must touch `Sources/JevPasteApp/SmartPasteApplication.swift`, `ask` first.

## Report format
`[chatgpt] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
