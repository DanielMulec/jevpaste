# Brief — Run the real-app acceptance suite (issue #29)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/acceptance`, branch `acceptance` (forked from `main` @ aeb2dd9). Your supervisor is
the Pi session with intercom id **`01a0d43b-ff28-7477-8f04-c6e79ab693b4`** (cwd
`/Users/danielmulec/Projekte/experiments/jevpaste`). Daniel (owner) speaks **only through the supervisor**. You
are the only worker; the installed app is yours once the supervisor says "install now".

Communication protocol:
- `intercom send <supervisor>` one line after every numbered step: `[accept] step N done — <fact>`.
- `intercom ask <supervisor>` (blocking) at each **GATE**; prefix `[accept]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`. Never print history rows
  other than `JEVPASTE-…` fixtures. No payloads in logs or reports — counts, kinds, timestamps, verdicts only.

## Read first (in this order)
1. `gh issue view 29` — your ticket (assigned to Daniel; that is the claim, leave it).
2. The criteria you execute: `gh issue view 5 --comments` (last comment: targets, hard rules, ambiguity,
   insufficient context, insert-only, responsiveness targets). The slice plan and acceptance rules:
   `gh issue view 16 --comments` (last comment, "Acceptance (every slice)", row 8).
3. `gh issue view 1` — map **Notes** (hard rules) and **Decisions so far** — every line; the decisions are what
   the suite verifies. Zoom into: [Implement Direct Paste for single-line items](https://github.com/DanielMulec/jevpaste/issues/34)
   (single line → Direct Paste, `via=directPaste`), [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27)
   (open question: Rejev-paste of a single-line item), [Implement Pre-check rules](https://github.com/DanielMulec/jevpaste/issues/20),
   [Restore Smart Paste in the ChatGPT desktop app](https://github.com/DanielMulec/jevpaste/issues/33)
   (`com.openai.codex` **is** the ChatGPT desktop app; "Waking ChatGPT…" on a cold first press is expected),
   [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14)
   (behaviour matrix per target).
4. `CONTEXT.md`, `docs/design/paste-attempt-state-machine.md`, `docs/design/direct-paste.md`,
   `docs/design/pre-checks.md`, `docs/design/hardening.md`, `docs/HANDOFF.md` ("Durable notes", "Wave-5/6
   lessons" — fixture and payload rules, Herdr focus gating, `JevGateway` logs at INFO → use `--info`).
5. Tools: the Chrome DevTools MCP server `chrome-devtools` is configured for Pi (`~/.pi/agent/mcp.json`). It
   is lazy: run `mcp({connect:"chrome-devtools"})` first, then `mcp({server:"chrome-devtools"})` to see its ~30
   tools (`list_pages`, `new_page`, `select_page`, `take_snapshot`, `click`, `fill`, `evaluate_script`,
   `close_page`, …). It attaches to Daniel's **running** stable Chrome and drives real tabs. Herdr CLI (`herdr
   tab create/pane get/pane send-keys/pane read`) drives terminal panes. `gh` is authenticated.

## Scope — what the suite proves
Execute the #5 criteria on the five v1 targets with **synthetic content only**, and record a result matrix:
Chrome (labelled inputs + a textarea), Herdr pane inside Ghostty (shell prompt), a plain native text field
(TextEdit, baseline), WhatsApp for macOS ("Message yourself"), ChatGPT desktop app. **Nothing may be sent,
executed or submitted.** Per target, the cases:
- **A. Direct Paste**: single-line item → inserted whole, `via=directPaste`, no Jev call, ✓.
- **B. Jev paste, unambiguous**: multi-line item with exactly one plausible value for a labelled field
  (Chrome/TextEdit only — Jev refuses everything in unlabelled targets; record that fact for terminals,
  WhatsApp, ChatGPT rather than forcing it).
- **C. Ambiguity**: three emails for an "Email" field → chooser appears; Esc cancels, nothing inserted.
- **D. No suitable match**: multi-line item with no value for the field → "No suitable match", nothing inserted.
- **E. Pre-checks**: secure field → refused; suspected secret on the clipboard → refused; no editable focus →
  refused. Zero Jev calls, zero pasteboard writes on each.
- **F. Multi-line safety**: a multi-line Paste Result into a terminal/WhatsApp/ChatGPT must not execute/send
  (reuse the #14 matrix as the reference; re-verify on the current build).
- **G. Rejev-paste**: pick a single-line item from the history panel, paste → Direct Paste of that item.
- **H. Clipboard restore**: after every paste, Daniel's real clipboard (snapshot before) is back byte-for-byte.
- **I. Responsiveness**: from the log, time from press to first visible feedback and to insertion; compare to
  the #5 targets (150 ms / 1 s / 5 s) — report, don't promise.

## Automation rule — do as much as possible without Daniel
- **Chrome: fully automated.** Open `data:` pages via DevTools MCP, focus the field (`click`), read the field
  value after the paste (`evaluate_script` on the input — synthetic values only), clear it, and assert. Do not
  touch Daniel's other tabs; close what you open.
- **Terminal: fully automated** via Herdr (gate every synthetic step on `herdr pane get <id>` focused=true and a
  frontmost-app check; discard buffers with `C-c`; read verdicts with `herdr pane read`).
- **The ⌘⇧V press**: worker shells have no Accessibility, so the keystroke cannot be posted from you. **GATE A
  decides the trigger**: propose the smallest scaffold that lets you fire the production app's press path
  without Daniel (e.g. `SIGUSR1` → the same handler as the hotkey, exactly as the never-merged
  `multiline-probe` branch did in `MultilineProbe.swift`; enabled only by a launch flag such as
  `--accept-signal-trigger`, off by default, never in the packaged default launch). Justify it as **test
  scaffolding** — Daniel challenges per-app hacks and unjustified scaffolding — and say whether it stays in
  `main` behind the flag or lives only on this branch. Do not build it before GATE A.
- **TextEdit**: open the file for him with `open`; focus via AppleScript if it works, else it is a Daniel step.
- **WhatsApp and ChatGPT: Daniel presses.** Batch every Daniel step into **one** block, staged completely
  (apps open, caret placement described in plain words, clipboard set by you), relayed through the supervisor.
  His menu bar auto-hides: for anything shown under the menu-bar icon, say "move the mouse to the top edge".
  He must not copy anything during the block — say so.
- Log reading: `log show --predicate 'subsystem == "…"' --info --last …` (find the subsystem in the code); use
  `--info` or you will miss `JevGateway` lines.

## Steps
1. `docs/acceptance/plan.md` (≤ 120 lines): the target × case matrix with, per cell, *automated* / *Daniel* /
   *n/a (why)*; fixtures (one pure value per line, `JEVPASTE-ACC-…` markers on their own line); the trigger
   proposal; the exact Daniel block (plain words, why per step); the log command. **GATE A**: ask with the path
   and the trigger proposal in three lines.
2. Build the trigger (if approved) TDD-style, `make check` green, small commits.
3. Automated runs (Chrome, terminal, TextEdit if scriptable) after the supervisor says "install now". Record
   every cell with timestamps and log lines in `docs/acceptance/results.md`. Restore Daniel's clipboard after
   each run and prove it.
4. **GATE B**: ask with the automated matrix so far and the staged Daniel block. Then the live block runs
   through the supervisor; you record his words verbatim per step and reconcile against the log.
5. Push. Post a report comment on issue #29: matrix (all cells), responsiveness numbers, failures with
   evidence, what was automated vs. human, the trigger decision, commits, open questions. **GATE C**: ask with
   the comment URL, then end your turn. Do not merge, do not close the issue, do not reinstall.

## Rules
- Swift 6 strict concurrency, Swift Testing, ≤ 400 lines per file. No new dependencies without `ask`. No
  per-app hacks in production code. Commit small on `acceptance`; push after each gate. Do not merge.
- A failing cell is a finding, not something to fix on this branch: record it, `ask`, and the supervisor
  decides whether it becomes a ticket.
- Production JevPaste (`~/Applications/JevPaste.app`, clean `main` aeb2dd9, Open-at-Login on) is running; if
  your build needs a flag, quit it, launch yours with the flag, and relaunch the production one at the end.

## Report format
`[accept] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
