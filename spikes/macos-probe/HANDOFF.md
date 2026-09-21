# Handoff — macOS probe for ticket #11 (session 2 → session 3)

You are the successor Pi session in this worktree (`~/.pi/worktrees/jevpaste/macos-probe`, branch `spike/macos-probe`, still at `00abbee`, NOTHING committed yet). You must run as **anthropic/claude-opus-5 with thinking xhigh** — verify via `PI_MODEL` / `PI_REASONING_LEVEL` and state it in your first message. Daniel Mulec sits at this Mac in front of your pane. The planning session ("jevpaste" main, cwd `/Users/danielmulec/Projekte/experiments/jevpaste`) supervises you over intercom.

## Rules (unchanged, do not re-litigate)
- Throwaway probe; synthetic content only (`JEVPROBE-*`); never log/print/write real clipboard or field payloads — lengths/types/sha only. Titles are hashed (`String?.redacted`); placeholders are verbatim on purpose.
- No network, no Jev, never read `~/.config/jevpaste/env`. No `tccutil`, no TCC.db edits.
- **DO NOT REBUILD** the probe unless unavoidable: ad-hoc signing ⇒ new cdhash ⇒ Accessibility grant silently orphaned (Settings still shows ON, `AXIsProcessTrusted()` false). If a rebuild is truly needed, ASK the supervisor first; Daniel then has to remove + re-add the entry in System Settings → Privacy & Security → Accessibility.
- 400 lines/file ceiling. Report facts; "decision implications" only as OPTIONS.
- Communication protocol (agreed, keep it): (1) all click/permission steps to Daniel in YOUR pane only, one-word answers `done/nothing/failed`; (2) intercom **ask** (blocking) to the supervisor before starting each target; (3) intercom **send** with the matrix row after each target; (4) anything unexpected/rebuild → ask first; (5) final ask with RESULTS.md path + sha, do not push until replied. Zero-cost reads (`perm`, `id`, tailing the log) are ungated.

## How to run (granted binary — use exactly this)
```
cd /Users/danielmulec/.pi/worktrees/jevpaste/macos-probe/spikes/macos-probe
rm -f /tmp/jevprobe.in && mkfifo /tmp/jevprobe.in && (sleep 100000 > /tmp/jevprobe.in &)
open -n ~/Desktop/MacOSProbe.app --args --fifo /tmp/jevprobe.in --log "$PWD/probe-transcript.log"
echo "<cmd>" > /tmp/jevprobe.in       # send commands
```
Granted bundle: `~/Desktop/MacOSProbe.app` (bundle id `com.jevpaste.macos-probe`, cdhash `f149456a4f2213fe7fd5e6dd27615e9ba5ab012f`; repo copy `build/MacOSProbe.app` identical). Relaunch is free; rebuild is not. Probe is currently **not running** (quit cleanly). `build/`, `.build/`, `*.log` are gitignored — the transcript is never committed.

Commands: `help env perm ask-ax ask-post ask-listen ladder detectvalues watch <ms> [read] unwatch hk carbon|tap|monitor|off|status arm identify|full|paste|axinsert|drift|none id ctx timings <n> paste <restoreDelayMs> axinsert race <windowMs> drift <ms> wake <attr> ind status|panel|alert|notify|notify-auth after <s> <cmd> copytest <n> note <text> quit`.
Sources: `Sources/MacOSProbe/{main,Commands,Env,Hotkeys,Clipboard,AXProbe,ContextProbe,Insertion,Indicator,Log}.swift`, `scripts/make-app.sh`, `test-page.html` (synthetic Chrome page: email input, textarea, password, React-style controlled input with JS mirror).

## Measured so far (all on macOS 26.6.2, CLT-only Swift 6.3.3)

**Permissions**
- Carbon `RegisterEventHotKey` ⌘⇧V fires with ZERO TCC grants; also fires with `IsSecureEventInputEnabled()==true` (password field). CGEventTap and NSEvent global monitor also register once Accessibility is on; 400 ms dedup needed because Carbon+tap both see the press.
- Accessibility went live in the running process without relaunch. `CGRequestPostEventAccess` / `CGRequestListenEventAccess` returned true with NO separate dialog after Accessibility was granted.
- **RESOLVED (session 3, visually verified by Daniel):** MacOSProbe appears under Bedienungshilfen/Accessibility ONLY and is **absent entirely** from Eingabeüberwachung/Input Monitoring (not present-and-off — absent), while `CGPreflightPostEventAccess` and `CGPreflightListenEventAccess` both report true. On macOS 26.6.2 a single Accessibility grant covers BOTH event posting and event listening. Input Monitoring is not a separate hurdle: one grant, one row, one user click.
- `NSPasteboard.general.accessBehavior` reported `alwaysAllow` on a never-seen ad-hoc bundle; no pasteboard privacy alert ever appeared. Ladder/detectvalues ran; check transcript before re-running.
- Ad-hoc cdhash-bound grant: build `317c0640…` granted → rebuilt → Settings ON but `AXIsProcessTrusted=false` across running/relaunch/direct-exec; fixed by remove + re-add for `f149456a…`. Headline fact.

**Chrome (complete; full row was sent to the supervisor — reproduce it in RESULTS.md from the transcript)**
- Capture: 4 types incl `org.chromium.source-url` provenance; content read ~2 ms; no nspasteboard.org markers.
- AX: tree asleep until one ordinary `AXChildren` walk wakes it (3× noValue → success after `ctx`). `AXEnhancedUserInterface`=notImplemented, `AXManualAccessibility`=attributeUnsupported — rejected AND unnecessary. Before wake, ctx sees browser chrome only.
- Label contract (#7): title, placeholder, fieldset legend (AXGroup), page title (AXWebArea), AXURL, AXDOMIdentifier — all from ordinary AX. Context: 223 nodes / 143 text / ~3.9 k chars / 54–68 ms; 2000 chars at 43–54 ms.
- Secure: `AXSecureTextField` subrole + global `IsSecureEventInputEnabled` both fire independently. **AXValue/AXSelectedText are reported settable even on the password field** — the refusal must be ours.
- Insertion A (pasteboard swap + synthetic ⌘V + restore): works in input and textarea, verified by AXValue chars/sha read-back. Clipboard restored byte-identical (4 types) in 9/9 cycles. Restore delay: 0 ms LOSES the paste; 40/120/250 ms OK. Full battery 126–128 ms.
- Insertion B (AX setter): **silent failure** — settable=true, returns success in 0.1 ms, nothing rendered, JS mirror empty, read-back chars=0. 4×.
- Race: foreign copy 150 ms into a 300 ms window → guard tripped, restore abandoned (correct). Drift: none idle over 800 ms; real drift whenever Daniel switches apps → measure at hotkey time.
- Visible failure: status item 1.7–3.2 ms, non-activating NSPanel 8–16 ms, focus preserved. Probe bug: one panel per press, only last retained → 3 leaked panels. Note as UX lesson (single-instance indicator).

**Ghostty / Herdr (COMPLETE — session 3). Session 2's "silent failure" reading was a FALSE NEGATIVE and is overturned.**
- Ghostty exposes one `AXTextArea` ("text entry area"), help chars=21, no title/placeholder/description. `settable AXValue/AXSelectedText/AXSelectedTextRange = false` ⇒ path B not offered — an honest refusal, unlike Chrome advertising settable=true and doing nothing.
- Correction to the session-2 record: the `cat -v` isolation test (`after 20 paste 250`) was NOT aborted. It fired at t=547.311 (payload JEVPROBE-A-15, Cmd+V posted in 0.37 ms, clipboard restored intact, totalMs=253.05, AXValue unchanged). Only the human observation was missing. Preserved in `probe-transcript.session2.log`.
- **Insertion A WORKS.** Bracketed arrival proven at a shell with a DECSET-2004 reader: `herdr pane read` showed `^[[200~JEVPROBE-A-1^[[201~`. Testing caveat: a bare `cat -v` under-reports bracketing, because zsh disables bracketed-paste mode while a foreground command runs — the reader must set mode 2004 itself.
- **Primary battery in a real IDLE Pi chat editor** (`herdr agent start --kind pi`, status idle): all four delays landed — 20 ms (23.25 ms total), 60 (62.04), 120 (121.84), 250 (253.31). Editor held `JEVPROBE-A-2JEVPROBE-A-3JEVPROBE-A-4JEVPROBE-A-5`; nothing submitted (no newline, status stayed idle), cleared afterwards. Clipboard restored byte-identical 5/5. **20 ms suffices here vs Chrome losing the paste at 0 ms** — Ghostty consumes the pasteboard synchronously.
- **AX read-back is INVALID on terminals:** valueAfter sha == valueBefore sha in 5/5 cases including the four that demonstrably landed. `AXValue` length is pinned at 13265 on every read while its sha changes every second on its own; refresh lag exceeds 253 ms. Never use AX read-back to verify insertion into a terminal.
- **Multiplexer finding:** 13265 chars ≈ 213 cols × 62 rows = the ENTIRE Ghostty window incl. Herdr's sidebar and both panes (scratch pane's own visible text was 152 chars, driver pane's 1597). Herdr panes are invisible to AX — ONE AXTextArea per window. jevpaste cannot know which pane receives a paste, and any scraped context includes unrelated panes and another agent's transcript (targeting limitation + privacy consideration).
- focusedElementLookup: 7.27 ms cold, 0.28–0.80 ms warm — no wake walk needed, unlike Chrome. Ancestry depth 5. SECURE-FIELD verdict=no.
- **Label contract (#7) on terminals is essentially EMPTY:** title/placeholder/description all nil; only AXHelp (21 ch) and one ancestor AXGroup description (13 ch). No URL, no DOM id. OPTIONS (not a decision): (i) treat terminals as a no-context target; (ii) scrape the window and accept cross-pane bleed; (iii) detect multiplexers and refuse context.
- Supervisor asks for this target: primary battery in an IDLE Pi chat editor in a scratch Herdr pane (not the supervisor's, not yours); secondary at a plain shell; never submit (no newline); record whether Ghostty delivers the paste bracketed (`cat -v` shows `^[[200~ … ^[[201~`); note that terminal AXValue is live scrollback so read-back is only meaningful when nothing else writes to that surface. Suggested discriminator: run `cat -v` in the scratch pane, `after 15 paste 120`, Daniel focuses the pane and reports what appeared — that separates (c) from (a)/(b) immediately; then compare `id` output's AXValue chars against the scratch pane vs your own pane to test (a).

**MANDATORY: drive Herdr yourself for the Ghostty/Herdr target.** You run inside a Herdr pane (`test "$HERDR_ENV" = 1`; print `herdr --skill` once and read it). Do NOT ask Daniel to open panes, run `cat -v`, or read what appeared. Use the `herdr` CLI (most commands return JSON — read IDs from responses):
- `herdr pane split --current …` to create a scratch pane; `herdr pane run <id> 'cat -v'` for the bracketed-paste/arrival test; `herdr agent start <id> pi` (or `herdr pane run <id> pi`) for a real idle Pi chat editor; `herdr agent wait <id> --state idle`.
- `herdr pane focus <id>` puts keyboard focus on that pane inside Ghostty. Ghostty must ALSO be the frontmost macOS app: use `open -a Ghostty` (no Automation permission needed) or ask Daniel for one click, then `after 3 paste 120` from the probe FIFO so focus has settled.
- Verify with `herdr pane read <id>` — that is the ground truth for "did the paste land" and "was it bracketed" (`^[[200~JEVPROBE-A-n^[[201~` under `cat -v`). Do not rely on Ghostty's AXValue read-back; record it only as a secondary observation. Compare `id`'s AXValue chars against `herdr pane read` of the scratch pane vs your own pane to settle hypothesis (a).
- Close scratch panes when done (`herdr pane close <id>`). Never target the supervisor's pane or your own pane for insertion (`herdr pane current` tells you yours; ask the supervisor for its pane id if unsure).
- Report to Daniel only what he genuinely must do (an app switch, a permission), one-word answers.

**Still to do after Ghostty:** WhatsApp desktop, ChatGPT desktop app, TextEdit/Notes baseline (same battery each; WhatsApp/ChatGPT are Electron/Catalyst-ish — watch for the same silent AX-setter failure and whether a Send button enables). Then optional, only with Daniel's explicit yes: self-signed code-signing cert → re-sign → grant once → rebuild+re-sign → does `AXIsProcessTrusted` survive. Then RESULTS.md (≤400 lines, structure in the original brief), README paragraph, commit, ask supervisor, push.

## Daniel-visible loose ends (fix in your first minutes)
- Chrome has `test-page.html` open with JEVPROBE text in fields — harmless.
- A scratch Ghostty tab may still be running `cat -v` — ask Daniel to Ctrl-C it.
- Clipboard currently holds synthetic `JEVPROBE-FOREIGN-COPY` (21 chars); Daniel's real clipboard content was intentionally abandoned by the race guard. Tell him.
- Menu bar item is gone (probe quit). No stuck panels known.
