# Brief — the deferred Chrome rows of "Read nearby text around the text cursor" (issue #51, merged)

You are a fresh Pi session (`anthropic/claude-opus-5-5:high`). This is a small **evidence task** on a slice that is
already merged (`main` 5a44ab7). It adds no product code. Your supervisor's intercom id is in your launch prompt;
use exactly that id. Daniel (owner) speaks only through the supervisor.
Protocol: `intercom send <id> "[chrome-rows] step N done — <fact>"` after each step; `intercom ask` when blocked.
Never print `~/.config/jevpaste/env`. Never log or print item text, surrounding text, page text or window titles:
only `JEVPASTE-…` marker booleans, lengths, offsets, pids, bundle ids and status codes.

## Read first
1. The report and resolution on issue #51: `gh issue view 51 --comments`. The report's section "Chrome rows —
   deferred, ready to run" is your script. The resolution lists them as open item 1.
2. `docs/design/cursor-context.md` (the rule) and `docs/acceptance/run-2026-09-26-cursor-context.log` (the format
   your log follows; it holds positions and markers, never literal text).

## Two worktrees
- **Probe** (build and run from here; never merged): `git worktree add ~/.pi/worktrees/jevpaste/chrome-rows-probe
  origin/cursor-context-probe --detach`. It holds the instrumented build (7c03d9d) and the fixtures in `live51/`.
- **Evidence** (the only thing that lands in `main`): `git worktree add -b cursor-chrome-rows
  ~/.pi/worktrees/jevpaste/chrome-rows main`. Your log goes to
  `docs/acceptance/run-2026-09-26-cursor-context-chrome.log` here. It's docs only, so no `swift build` is needed
  before committing; if the pre-commit hook insists, run `npm ci` and one plain `swift build` first.

## Rows
- **(b) long `<textarea>`, caret in the middle**: `live51/gate-a.html` (caret set between BEFORE and AFTER on load).
  First the probe (`sig.sh com.google.Chrome USR2`) for whether a cursor is reported and at which UTF-16 location.
  Then the live attempt: expect `BEFORE=true AFTER=true FARSTART=false FAREND=false`, surroundingChars=2000.
- **(c) short labelled field**: `live51/short.html`. This is the page-walk regression check: expect the page and
  label markers present and surroundingChars < 2000.

## Chrome
Daniel granted full Chrome DevTools rights on 2026-09-26 ("take all the Chrome rights"). You may use the
chrome-devtools MCP to open, focus and close your own test tabs, and to read the caret position via
`evaluate_script`. The `file://` pages alone are enough, though. Each new MCP connection makes Chrome show
"Allow remote debugging?": if your first MCP call hangs, `ask` the supervisor (Daniel has to click) instead of
waiting. Before any `close_page`, re-list the pages and verify the title; page ids shift. Close only your own tabs.
Gate every trigger on the frontmost app being `com.google.Chrome` **and** your test tab being the active one
(`select_page` + bring to front). `hasFocus()` is not a key-window check.

## The app
Production is quit for the run and restored afterwards, in this order:
1. Save the clipboard to the vault.
2. Quit production by pid.
3. Run the test instances with `open -n build/JevPaste.app --args …`.
4. Quit the test instances by pid.
5. **Restore the vault first**, then `open ~/Applications/JevPaste.app`. Log `pgrep` before and after.

Signals go only to your test pids; never by name. No secret fixture: paste only the `# JEVPASTE-PASTE-51` marker
into the test textarea.

## Steps
1. Worktrees, build, fixtures copied to `/tmp/jevpaste-cursor-51`. `send`.
2. Rows (b) and (c) (one `ask` before quitting production, with the plan in one line). `send` the booleans.
3. Cleanup (as above; close your Chrome test tabs). Commit the log to `cursor-chrome-rows`, then
   `git push -u origin cursor-chrome-rows`.
4. Comment on issue #51 (`gh issue comment 51 --body-file <file>`): the Chrome rows and their numbers, plus one
   line on whether Chrome reports a real caret.
5. **Last step, mandatory:** `intercom send <id> "[chrome-rows] done — <comment URL>"`.

## Rules
Read-only outside your two worktrees and `/tmp/jevpaste-cursor-51`. Do not merge. If Chrome reports no usable
cursor on the textarea, that is a result: report it and don't change any code.
