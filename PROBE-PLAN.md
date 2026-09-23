# PROTOTYPE — multi-line Paste Result probe (issue #14, branch `multiline-probe`, never merged)

Question: does a multi-line Paste Result delivered by swap → ⌘V → 120 ms restore insert line breaks, get
stripped/flattened, or **send** the message? Measured per Target. Decision (refuse / warn / nothing) is the
supervisor's with Daniel.

## Mode
`JevPaste --multiline-probe <log-path>` (next to `--probe`, file `MultilineProbe.swift`). Same lifecycle as
`AdapterProbe`: resolve focused target → secure-field refusal → re-verify → snapshot **Daniel's real
clipboard** (no synthetic seed) → write payload → ⌘V → 120 ms → restore unless foreign copy → byte-for-byte
check. Quits after 30 presses or 45 min. Log = counts/verdicts only: target bundle id, variant, payload
line/LF/CR counts, restore verdict; **Chrome only** (read-back valid there) 500 ms later: all three markers
present, LF count, CR count and the field's total line count. Never field text, never clipboard text.
Production JevPaste is quit for the run (both would claim ⌘⇧V) and relaunched afterwards.

## Payloads (synthetic, every line starts with `#` on every target — terminal safety needs no bundle detection)
Deliveries cycle per successful press:
1. `LF`       `# JEVPASTE-ML-LINE-1\n# JEVPASTE-ML-LINE-2\n# JEVPASTE-ML-LINE-3`
2. `CRLF`     same with `\r\n`
3. `LF-TRAIL` variant 1 plus a trailing `\n` (a paragraph/section Candidate can end in a newline)

## Target order (lowest risk first) and per-target run script for Daniel
Before every target: click into the field so the caret blinks there. After each ⌘⇧V: look, then report;
clear the field (⌘A, Delete) before the next ⌘⇧V. Three presses per target (LF, CRLF, LF-TRAIL).
1. **Chrome textarea** — open `data:text/html,<textarea autofocus rows=8 cols=60></textarea>`.
2. **Chrome single-line input** — open `data:text/html,<input autofocus size=60>`.
3. **Ghostty shell prompt** — a fresh Ghostty tab at an empty zsh prompt, outside Herdr. Look: one multi-line buffer waiting for Return (bracketed paste) vs. lines executed (new prompts /
   "command not found: #"). After looking: Ctrl-C to discard, never Return.
4. **Herdr pane** — a scratch Herdr pane at an empty zsh prompt; same look and Ctrl-C as Ghostty.
5. **ChatGPT app** — a new throwaway conversation, caret in the composer. Look: message sent? line breaks in
   the composer? After looking: ⌘A, Delete.
6. **WhatsApp** — "Message yourself" chat, caret in the compose box. Look: message sent? line breaks?
   After looking: ⌘A, Delete. (If anything was sent: it went to Daniel himself only.)
Per press Daniel reports three facts: **line breaks visible (3 lines / 1 line / other)**, **message sent
(yes/no)**, anything odd.

GATE A (approved by Daniel via supervisor): payload + 3 variants, order incl. Herdr, no synthetic seed,
production app quit during runs.

## Result matrix (filled from Daniel's report + log; standalone Ghostty dropped by Daniel)
| # | target | variant | line breaks inserted | newlines stripped/flattened | sent | read-back (Chrome) |
|---|---|---|---|---|---|---|
| 1 | Chrome textarea | LF | yes, 3 lines | no | n/a | markers 3/3, lf=2 cr=0 lines=3 |
| 2 | Chrome textarea | CRLF | yes, 3 lines | CR dropped (CRLF→LF) | n/a | markers 3/3, lf=2 cr=0 lines=3 |
| 3 | Chrome textarea | LF-TRAIL | yes, 3 lines + empty 4th (caret) | no | n/a | markers 3/3, lf=3 cr=0 lines=4 |
| 4 | Chrome input | LF | no, 1 line | flattened: each LF → space (eyewitness) | n/a | markers 3/3, chars=62 lf=0 cr=0 lines=1 |
| 5 | Chrome input | CRLF | no, 1 line | flattened: each CRLF → space (eyewitness) | n/a | markers 3/3, chars=62 lf=0 cr=0 lines=1 |
| 6 | Chrome input | LF-TRAIL | no, 1 line | flattened; trailing LF dropped (63→62 chars) | n/a | markers 3/3, chars=62 lf=0 cr=0 lines=1 |
| 7 | Herdr (zsh) | LF | yes, 3-line buffer waiting at prompt | no | no (not executed; C-c → clean prompt, 0 "command not found") | n/a (herdr pane read) |
| 8 | Herdr (zsh) | CRLF | yes, but 5 lines: each CRLF shown as two breaks (blank line between) | no (CR became an extra break) | no | n/a (herdr pane read) |
| 9 | Herdr (zsh) | LF-TRAIL | yes, 3 lines + empty 4th line in the buffer | no | no (trailing LF did not execute) | n/a (herdr pane read) |
| 10 | ChatGPT app (com.openai.codex) | LF | yes, 3 lines | no | **no** | n/a (unresolved-delivery) |
| 11 | ChatGPT app (com.openai.codex) | CRLF | yes, 3 lines (no blank lines reported) | CR not shown as extra break | **no** | n/a (unresolved-delivery) |
| 12 | ChatGPT app (com.openai.codex) | LF-TRAIL | yes, 3 lines + empty trailing line | no | **no** (trailing LF did not submit) | n/a (unresolved-delivery) |
| 13 | WhatsApp (Message yourself) | LF | yes, 3 lines | no | **no** | n/a |
| 14 | WhatsApp (Message yourself) | CRLF | yes, 3 lines | CR not shown as extra break | **no** | n/a |
| 15 | WhatsApp (Message yourself) | LF-TRAIL | yes, 3 lines + empty trailing line | no | **no** (trailing LF did not submit) | n/a |

Run 1 note: Daniel pressed ⌘⇧V five times in the textarea (operator extra presses, confirmed; no double-fire).
Presses 4 (LF) and 5 (CRLF) read back identical to rows 1–2. Probe relaunched so target 2 starts at LF.

Method note (Herdr run): standalone Ghostty dropped by Daniel; the terminal target is a scratch zsh pane
(wC:p15, own tab wC:t6) in the running Herdr, triggered by SIGUSR1 to the probe (same press path, hotkey
bypassed; my shell has no Accessibility). First attempt misdelivered: `herdr tab focus wC:t6` via CLI was a
no-op and the trigger was not gated on the focus check, so press 1 (LF) was pasted into the supervisor's pi
editor pane (inert # text, clipboard restored). Fixed: Daniel clicks the tab himself; every trigger is gated on
p15 focused=true and frontmost app = Ghostty. Probe relaunched so the retry starts at LF.
Herdr retry (log -4): all 3 presses gated focused=True + front=Ghostty, restored byte-for-byte. One unplanned
extra key: I sent Ctrl-L once to the scratch pane after press 1 (no effect on results). Tab closed after.

ChatGPT app note: on Daniel's Mac the ChatGPT app IS com.openai.codex (his daily target). MacInterop's resolver
refused every press there: focused element read returns kAXErrorNoValue (-25212) even after the Chromium wake walk
→ **production resolver gap, independent of #14** (the supervisor raises a map ticket). To measure multi-line
anyway, a probe-only fallback delivers when front=com.openai.codex AND focused=noValue ("unresolved-delivery").
That bundle pin is **probe-only scaffolding**; the production fix must be app-agnostic. Daniel made 7 presses
(LF, CRLF, LF-TRAIL ×2, LF); none sent; he saw 3 lines, with an extra empty line "every now and then" — matches
the LF-TRAIL presses 3 and 6 (log -6). Per-press eyewitness not separated, so the CRLF row rests on "3 lines".
WhatsApp (log -7): exactly 3 presses, resolver accepted net.whatsapp.WhatsApp, restored byte-for-byte each.

## Outcome
Decision (GATE C, accepted by Daniel via supervisor): **no per-Target refusal or warning for multi-line Paste
Results.** No target sent or executed on any variant, including a trailing newline; submission is the Return
key event, and the pasted text is inserted (bracketed in zsh). Flattening in single-line inputs and CR doubling
in zsh are the targets' own ⌘V behaviour; the app still delivers the verbatim excerpt. Optional follow-up
(not a refusal): prefer single-line Candidates when the Target role is AXTextField.
Not measured: terminals/programs without bracketed paste (lines would execute; the `#` payload made this safe).
Side finding: com.openai.codex resolver gap (see ChatGPT app note) — supervisor raises a map ticket.
Production app reinstalled from main cc556cc after the runs.

Logs (counts/verdicts only): docs/probe-logs/multiline-1…7.log (1 textarea, 2 input, 3 misdelivery, 4 Herdr,
5 ChatGPT diagnostic, 6 ChatGPT unresolved-delivery, 7 WhatsApp).
