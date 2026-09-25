# Acceptance suite — plan (issue #29)

Criteria: [Define representative workflows and app acceptance criteria](https://github.com/DanielMulec/jevpaste/issues/5)
(last comment). Build under test: `acceptance` = `main` aeb2dd9 + the trigger below. Synthetic content only;
nothing sent, executed or submitted. Results go to `docs/acceptance/results.md` (timestamps, outcome kinds, counts).

## Matrix — who performs each cell
| case | Chrome | Herdr/Ghostty | TextEdit | WhatsApp | ChatGPT |
|---|---|---|---|---|---|
| A Direct Paste (single line) | auto | auto (+ trailing-newline variant) | auto¹ | Daniel² | Daniel² |
| B Jev, one value | auto (Email field) + B2 auto (textarea, multi-line result) | fact³ | fact³ | fact³ | fact³ |
| C ambiguity → chooser, Esc | Daniel (Esc)⁴ | n/a³ | n/a³ | n/a³ | n/a³ |
| D no suitable match | auto | = fact³ (auto) | auto¹ | = fact³ (Daniel²) | = fact³ (Daniel²) |
| E secure field | auto (`type=password`) | auto, attempt⁵ | n/a (no secure field) | n/a | n/a |
| E suspected secret | auto | auto | auto¹ | Daniel² | Daniel² |
| E no editable focus | auto (click page body) + auto (Finder frontmost) | — | — | — | — |
| F multi-line safety | n/a (not send-capable) | auto | n/a | Daniel² | Daniel² |
| G Rejev-paste (single-line) | Daniel selects, auto trigger + read-back⁶ | n/a (same path) | n/a | n/a | n/a |
| H clipboard restore | auto, every paste | auto | auto | auto (digest) | auto (digest) |
| I responsiveness | auto (triggered presses) | auto | auto | log only | log only |

1. TextEdit: `open -a TextEdit /tmp/jevpaste-acc/textedit.txt` makes it frontmost with the caret at the start.
   Read-back from the autosaved file (no permission needed); if TextEdit has not autosaved within 30 s, the log
   verdict stands and the text check moves into the Daniel block (one glance).
2. WhatsApp/ChatGPT: Daniel only places the caret; I fire the presses (trigger) after a frontmost-bundle check, he
   then says what he sees. If he prefers, he presses ⌘⇧V himself — same cells.
3. Fact, not forced: unlabelled targets (shell prompt, TextEdit, composers) — Jev answers *none of these*
   (known from the ChatGPT resolver ticket). A multi-line item there → `noSuitableMatch via=jev`, nothing inserted.
   That is also what F measures on this build: no multi-line Paste Result can reach those targets today; the
   delivery-path matrix of the multi-line ticket (#14) is the reference, and the trailing-newline Direct Paste
   ("not executed / not sent") is the re-verification on the current build.
4. The chooser needs a real Esc (worker shells cannot post keys). Staged by me, Daniel presses ⌘⇧V and Esc.
   Kept out of the automated run: an open chooser would block every later attempt.
5. `sudo -k; sudo -v` in the scratch pane → Ghostty's password prompt enables secure input → expect
   `refused.secureField`; C-c afterwards. If Ghostty does not flag it, recorded as a finding (the paste would sit
   unsubmitted in the password buffer; no newline).
6. The history panel needs a click/Enter. Daniel: open it, type `REJEV`, Enter; focus returns to Chrome; I fire.

## Fixtures (one pure value per line; `JEVPASTE-ACC-…` markers on their own line)
- A: `JEVPASTE-ACC-A-CHROME@example.org` (per target a different suffix); terminal: `# JEVPASTE-ACC-A-TERM`
  and `# JEVPASTE-ACC-A-TERM-NL` + `\n` (a comment even if it ever ran); WhatsApp/ChatGPT: `JEVPASTE-ACC-A-WA`
  + `\n` and `JEVPASTE-ACC-A-GPT` + `\n` (trailing newline = the send hazard).
- B: `JEVPASTE-ACC-B` / `Jane Roe` / `acc.b@example.org` / `+49 30 1234567`. B2 (textarea "Shipping address"):
  `JEVPASTE-ACC-B2` / blank / `Example Street 1` / `10115 Berlin` / blank / `+49 30 1234567`.
- C: `JEVPASTE-ACC-C` / `acc.c1@example.org` / `acc.c2@example.org` / `acc.c3@example.org`.
- D: `JEVPASTE-ACC-D` / `Berlin` / `10115` (no email for the Email field).
- E secret: `ghp_JEVPASTE0000000000000000000000000000`. G: `JEVPASTE-ACC-REJEV@example.org` (then a newer copy, so it is older).
- Chrome page (`data:` URL, opened and closed by me): labelled `Email` input, `Shipping address` textarea,
  `Password` input, a plain paragraph for the no-focus case.

## Trigger proposal (GATE A)
`--accept-signal-trigger` launch flag → `SIGUSR1` fires the **same** `onPress` as ⌘⇧V. Shape: a `Hotkey`
decorator `SignalTriggeredHotkey(wrapping: GlobalHotkey, trigger: SignalPressTrigger(SIGUSR1))` placed *inside*
`GrantCheckingHotkey`, so the grant check, pre-checks, Direct Paste, Jev, chooser, delivery and restore are all
production code; only the key-press source is added. It logs `acceptance trigger (SIGUSR1)` at notice level —
the press timestamp case I needs; production logs no press. Off by default; the flag is read
once in `MenuBarApplication`; Open-at-Login / Finder launches never pass it. ~40 lines + tests (fake trigger:
presses forwarded from both sources; flag absent → no signal source installed).
Why scaffolding, not a hack: app-agnostic (no bundle ids), no production behaviour change, and worker shells have
no Accessibility, so without it every cell needs Daniel. **Recommendation: keep it in `main` behind the flag** —
`make acceptance` is already a placeholder and #36/#35/#31 will need re-runs. Alternative: branch-only (like
`multiline-probe`), rebuilt for each re-run.

## Run setup (automated, after "install now")
1. `make app` → signed `build/JevPaste.app` (jevpaste-dev). Quit production (`kill` its pid), launch
   `open -n build/JevPaste.app --args --accept-signal-trigger`; log must show `grant check at launch trusted=true`.
   `~/Applications/JevPaste.app` is not overwritten; at the end I quit mine and `open ~/Applications/JevPaste.app`.
2. Daniel's clipboard: snapshot all items/types to a 0600 file in a 0700 temp dir (never printed), sha256 digest
   recorded; restored + digest re-checked after each target block and at the end; file deleted.
3. Per press: `pbcopy` fixture → wait 0.5 s (capture polls every 100 ms) → digest + `changeCount` → gate
   (frontmost bundle via `lsappinfo`; Chrome: `document.hasFocus()` and `activeElement.id`; Herdr: `pane get`
   focused=true) → `kill -USR1 <pid>` → wait → read-back → digest/`changeCount` again → clear field / C-c.
   Gate fails → abort that cell, no trigger. A cold accessibility tree is waited for (Wake Wait, up to 3 s), no retry.
4. The Mac must stay awake and unlocked (`caffeinate -d` during runs); focus switches between Chrome, Ghostty and
   TextEdit, so Daniel should not type during the ~15 min automated window.
5. Leftovers: fixtures are recorded in Daniel's history (as in earlier runs); I do not delete them.

## Log command
`log show --predicate 'subsystem == "jevpaste"' --info --style compact --start "<run start>"`
(`--info` for `JevGateway`). Per cell I keep: trigger, `processing indicator shown`, `Jev decided … in N s`,
`chooser opened`, `delivering indicator shown`, `outcome <kind> via=<path>`. I = feedback (indicator or outcome)
− trigger; insertion ≈ outcome − 120 ms restore − trigger. Compared to 150 ms / 1 s / 5 s; reported, not promised.

## Daniel block (one sitting, ~6 min; can be another day; production or my build both work)
Before: I open everything (Chrome page, WhatsApp "Message yourself", ChatGPT app) and set the clipboard.
**Do not copy anything during the block.** His menu bar auto-hides: "move the mouse to the top edge".
1. Chrome tab "JevPaste acceptance" is in front, caret in *Email*. Press ⌘⇧V → a small list of three addresses
   appears under the menu-bar icon — move the mouse to the top edge to see it. Press Esc. Look: field stays empty.
   *Why: several emails fit — the app must ask, never guess, and Esc must cancel.*
2. Move the mouse to the top edge, click the clipboard icon → "Clipboard History…", type `REJEV`, press Enter.
   Say "selected". I then paste into the Email field and read it back.
   *Why: an older one-line item picked from history must paste whole, without Jev.*
3. WhatsApp is open on "Message yourself". Click into the message box, say "ready", then hands off ~30 s.
   I press three times; then say what is in the box. Look: one line `JEVPASTE-ACC-A-WA`, **not sent**; the
   other two presses show "No suitable match" and "Suspected secret" and add nothing. Then select all
   (⌘A) and Delete in the box. *Why: insert only; a trailing newline must not send.*
4. Same in the ChatGPT app composer (`JEVPASTE-ACC-A-GPT`). A cold start may show "Waking ChatGPT…"
   briefly — one press still pastes. Then ⌘A, Delete. *Why: same, for the ChatGPT app.*
Steps 3–4 (GATE B note): relay one sentence per press as it happens — press 1 "one line in the box,
nothing sent"; press 2 "No suitable match, nothing added"; press 3 "Suspected secret, nothing added".
