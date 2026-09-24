# Acceptance suite — results (issue #29)

Build: branch `acceptance` @ 52588e9 (`main` aeb2dd9 + acceptance trigger), `build/JevPaste.app` signed with
`jevpaste-dev`, launched with `--accept-signal-trigger` (pid 48747, 19:43:41, `grant check at launch trusted=true`).
Production `~/Applications/JevPaste.app` was quit for the window and relaunched at 19:50:23 (not overwritten).
Every press = `kill -USR1` after a frontmost-app gate (+ Chrome `document.hasFocus()`/`activeElement`, + Herdr
scratch pane focused=true and own pane focused=false). Full log (outcome kinds only, no payloads):
[`run-2026-09-24.log`](run-2026-09-24.log). Read-backs are of synthetic fixtures only (plan.md → Fixtures).

## Matrix (2026-09-24, automated window 19:43–19:50, Daniel away)
| case | Chrome | Herdr/Ghostty | TextEdit | WhatsApp | ChatGPT |
|---|---|---|---|---|---|
| A Direct Paste | ✅ ×2, value exact | ✅ at prompt, not executed; ✅ trailing `\n` stripped, line waits | ✅ autosaved file = fixture (35 B) | pending (Daniel block) | pending (Daniel block) |
| B Jev, one value | ✅ ×3 Email = `acc.b@…`; ✅ B2 textarea = 2-line address paragraph | fact: `noSuitableMatch via=jev` | fact: `noSuitableMatch via=jev` | pending (fact expected) | pending (fact expected) |
| C chooser + Esc | pending (Daniel block) | n/a (unlabelled) | n/a | n/a | n/a |
| D no suitable match | ✅ field empty, 0 writes | ✅ (= F run) prompt empty | ✅ file unchanged | pending | pending |
| E secure field | ✅ `refused.secureField` | ❌ **Herdr**: sudo prompt not secure → inserted (finding 1); ✅ plain Ghostty control | n/a | n/a | n/a |
| E suspected secret | ✅ `refused.suspectedSecret` | ✅ | ✅ | pending | pending |
| E no editable focus | ✅ page body; ✅ Finder | — | — | — | — |
| F multi-line safety | n/a | ✅ multi-line → `noSuitableMatch`; trailing-`\n` Direct Paste not executed | n/a | pending | pending |
| G Rejev-paste | pending (Daniel block) | n/a | n/a | n/a | n/a |
| H clipboard restore | ✅ every press | ✅ every press | ✅ every press | pending | pending |

H in detail: SHA-256 over all pasteboard items/types/bytes, taken after the fixture was copied and 2–4 s after
the press: identical on all 22 presses (inserting presses: `changeCount` +2 = own write + restore; refusals and
no-match: `changeCount` unchanged = zero pasteboard writes). Daniel's real clipboard (saved to a 0600 file before
the run, never printed) was restored after each target block; digest `ee966c1b…3c52d` matched the saved file
each time and still matched after production relaunched. Saved file deleted at the end.

## Presses (trigger → first feedback → outcome; insertion ≈ outcome − 120 ms Restore Window)
| time | target | case | outcome | indicator ms | outcome ms | insert ≈ ms | Jev s |
|---|---|---|---|---|---|---|---|
| 19:44:25.482 | Chrome Email | A | inserted directPaste | — | 154 | 34 | — |
| 19:44:41.066 | Chrome Email | B (cold) | inserted jev | 167 | 1459 | 1339 | 1.32 |
| 19:44:54.063 | Chrome textarea | B2 | inserted jev | 165 | 568 | 448 | 0.43 |
| 19:45:05.650 | Chrome Email | D | noSuitableMatch | 165 | 387 | — | 0.38 |
| 19:45:17.974 | Chrome Email | E secret | refused.suspectedSecret | — | 10 | — | — |
| 19:45:27.363 | Chrome Password | E secure | refused.secureField | — | 1 | — | — |
| 19:45:36.978 | Chrome body | E no focus | refused.noEditableTarget | — | 1 | — | — |
| 19:45:47.946 | Finder | E no focus | refused.noEditableTarget | — | 7 | — | — |
| 19:45:59.308 | Chrome Email | B | inserted jev | 167 | 849 | 729 | 0.70 |
| 19:46:08.498 | Chrome Email | B | inserted jev | 167 | 500 | 380 | 0.36 |
| 19:46:17.700 | Chrome Email | A | inserted directPaste | — | 135 | 15 | — |
| 19:46:47.064 | Herdr prompt | A | inserted directPaste | — | 131 | 11 | — |
| 19:47:01.122 | Herdr prompt | A + `\n` | inserted directPaste | — | 129 | 9 | — |
| 19:47:13.181 | Herdr prompt | F/D multi-line | noSuitableMatch | 159 | 470 | — | 0.47 |
| 19:47:23.459 | Herdr prompt | B fact | noSuitableMatch | 161 | 448 | — | 0.44 |
| 19:47:32.198 | Herdr prompt | E secret | refused.suspectedSecret | — | 4 | — | — |
| 19:47:47.322 | Herdr sudo prompt | E secure | **inserted directPaste** ❌ | — | 128 | 8 | — |
| 19:48:29.383 | plain Ghostty sudo prompt | E secure (control) | refused.secureField | — | 14 | — | — |
| 19:48:53.146 | TextEdit | A | inserted directPaste | — | 153 | 33 | — |
| 19:49:28.225 | TextEdit | B fact | noSuitableMatch | 181 | 664 | — | 0.64 |
| 19:49:36.651 | TextEdit | D | noSuitableMatch | 168 | 480 | — | 0.47 |
| 19:49:42.114 | TextEdit | E secret | refused.suspectedSecret | — | 14 | — | — |
No `JevGateway` line on any Direct Paste or refusal (zero Jev calls); no cold-AX wake (#36) occurred this run.

## I — responsiveness against the #5 targets (reported, not promised)
- **150 ms visible feedback: missed by design on the Jev path.** "Jev is choosing…" appeared 159–181 ms after the
  press (9 samples, median 167 ms): the 150 ms indicator timer starts after pre-checks and fires on the run loop.
  Refusals show their reason in 1–14 ms; Direct Paste shows ✓ at 128–154 ms (after the 120 ms Restore Window).
- **1 s p95 insertion:** Jev inserts at 380, 448, 729 ms warm and 1339 ms cold (first Jev call after launch). 5
  samples are too few for a p95; 1 of 5 over 1 s, the cold one. Jev decisions 0.36–1.32 s (median 0.47 s).
- **5 s timeout:** not reached (no forced slow Jev possible).
- Direct Paste inserts ≈ 8–34 ms after the press.

## Findings
1. **Terminal password prompts inside Herdr are not secure fields.** `sudo -v` in a Herdr pane: no
   `kCGSSessionSecureInputPID` (Ghostty's auto secure input does not see the no-echo prompt inside Herdr's pty);
   the pre-check passed and the single-line fixture was inserted into the password buffer (not submitted, no
   newline; C-c aborted sudo, "a password is required", no failed-auth attempt). Control: the same prompt in a
   plain Ghostty window (`open -na Ghostty --args -e …`) held secure input (PID = that instance) and was refused.
   → Herdr-specific gap. Supervisor: recorded as failed cell; ticket decision pending.
2. **150 ms feedback target is structurally out of reach on the Jev path** (see I). Design question, not a bug.

## Method notes
- Chrome field focus via `evaluate_script` (`focus()` / `blur()`) instead of `click`; `hasFocus()` gated each press.
- TextEdit read-back via its autosave of `/tmp/jevpaste-acc/textedit.txt` (no Automation permission needed); the
  window is left open (closing needs a key press); Daniel may close it without saving.
- Herdr scratch tab `acc-term` created with `--focus`, closed after the block; own pane focus verified restored.
- Fixtures remain in Daniel's Clipboard History (as in earlier runs).
