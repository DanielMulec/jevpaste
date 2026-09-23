# Brief — Verify multi-line Paste Results insert line breaks without sending (issue #14)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/multiline-probe`, branch `multiline-probe` (forked from `main`). This is a
**prototype** ticket: throwaway probe code on a throwaway branch that is **never merged**. Your supervisor is
the Pi session with intercom id **`01a0cf8d`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use
exactly that id. Daniel (owner) speaks **only through the supervisor** — every live step where Daniel acts is
an `intercom ask`, and you wait. **A parallel worker (harden) exists**; the installed app is shared — `make
install` only when a gate reply says go.

Communication protocol:
- `intercom send 01a0cf8d` one line after every numbered step: `[probe] step N done — <fact>`.
- `intercom ask 01a0cf8d` (blocking) at each **GATE** and for every live action; prefix with `[probe]`.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 14` — your ticket (already assigned to Daniel; that is the claim, leave it).
2. `~/.agents/skills/prototype/SKILL.md` — this is a logic-probe prototype; follow "Rules that apply to both".
3. `Sources/JevPasteApp/AdapterProbe.swift` and `Sources/JevPasteApp/MenuBarApplication.swift` — the existing
   `--probe <log-path>` mode: real adapters, Core's delivery order, counts/verdicts-only logging. You extend
   this pattern.
4. `gh issue view 11 --comments` (probe findings: read-back valid on Chrome only; AX setters lie elsewhere),
   `gh issue view 8 --comments` (delivery lifecycle), `gh issue view 1` **Notes** (hard rules), `CONTEXT.md`,
   `docs/signing.md` (why the signed identity keeps the Accessibility grant), `Makefile` (`make app` /
   `make install`).

## The question (from the ticket)
Paste Results are verbatim excerpts and may contain newlines. On send-capable Targets (WhatsApp, ChatGPT)
submission is believed to be the Return *key event*, not a newline character — expected, never measured.
Measure it. For each target record: **line breaks inserted / newlines stripped-or-flattened / message sent**.
The evidence feeds a decision (made by the supervisor with Daniel, not by you): does the lifecycle need a
per-Target refusal or warning for multi-line results?

Targets: WhatsApp (Daniel's "Message yourself" chat), ChatGPT app composer, Chrome `data:` **textarea**,
Chrome `data:` **single-line `<input>`**, Ghostty shell prompt (bracketed paste; Herdr too if Daniel wants).

## Safety rules (hard)
- Synthetic content only. Nothing may be *deliberately* sent; an unexpected send is itself a finding —
  minimize its blast radius: WhatsApp = "Message yourself"; ChatGPT = a throwaway conversation.
- Terminal payload lines start with `#` so nothing can execute even if bracketed paste fails.
- Payload suggestion (confirm at GATE A): `JEVPASTE-ML-LINE-1\nJEVPASTE-ML-LINE-2\nJEVPASTE-ML-LINE-3`
  (terminal variant `# JEVPASTE-ML-…`). Also one CRLF variant if cheap.
- Log counts and verdicts only — never field contents, never Daniel's clipboard text.
- Preserve and restore Daniel's real clipboard exactly as the existing probe does (snapshot → restore).

## Prototype rules (this branch only)
- Throwaway: no tests required, no polish; `git commit --no-verify` is allowed on this branch. Keep files
  ≤ 400 lines anyway. Do not touch Core logic; reuse `SystemClipboard`, `PasteKeystrokeInserter`,
  `AccessibilityTargetResolver`, `GlobalHotkey` as the existing probe does.
- Suggested shape: a `--multiline-probe <log-path>` mode next to `--probe`, same lifecycle: each ⌘⇧V delivers
  the multi-line payload to the focused target via swap → ⌘V → 120 ms restore; log target bundle id, payload
  line count, and (Chrome only) read-back verdicts: marker present, newline count in the focused value.
  Everything else (sent or not, visual line breaks) is Daniel's eyewitness report through the supervisor.
- The bundle must be built and installed **signed** (`make install`) so the Accessibility grant holds.

## Steps
1. Plan one page in the worktree (`PROBE-PLAN.md`, uncommitted or committed --no-verify): payload(s), the
   exact per-target run script for Daniel (what to open, click, press; what to look at), and the result matrix
   template. **GATE A**: ask with the payload one-liner and the target order; the supervisor confirms
   WhatsApp/ChatGPT safety choices with Daniel.
2. Implement the probe mode. Build (`make app`). **GATE B**: ask for install permission (the installed app is
   shared and currently the merged main build).
3. Live runs, one target per `ask`: give the supervisor the exact instruction block for Daniel and what to
   report back. After each answer, record the matrix row. Chrome rows also get the log's read-back verdicts.
4. When the matrix is complete: **GATE C**: ask with the full matrix and your recommendation (per-Target
   refusal / warning / nothing) plus reasoning in ≤ 5 lines.
5. After the supervisor's go: reinstall the production build — `ask` first; the supervisor will say from
   where (a clean `main` worktree) — and verify the status item runs again.
6. Commit the probe code and `PROBE-PLAN.md` (with the filled matrix) on `multiline-probe`, push the branch.
   Post a report comment on issue #14: the matrix, log excerpts (counts/verdicts only), branch link,
   recommendation. **GATE D**: ask with the comment URL, then end your turn. Do **not** merge, do **not**
   close the issue (the supervisor resolves the ticket).

## Report format
`[probe] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
