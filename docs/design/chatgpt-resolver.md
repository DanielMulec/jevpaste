# ChatGPT-app resolver gap — diagnosis plan

Ticket: [Restore Smart Paste in the ChatGPT desktop app](https://github.com/DanielMulec/jevpaste/issues/33).

## Observed failure
- Every ⌘⇧V in the ChatGPT app (`com.openai.codex`) refuses "No text field focused": system-wide
  `AXFocusedUIElement` → `-25212` (kAXErrorNoValue), also after `AXFocusSource`'s 300-node wake walk (#14 report).
- The app is **Electron**: `Contents/Frameworks/Codex Framework.framework`, `Resources/app.asar`,
  `ElectronAsarIntegrity`, `ChromiumBaseVersion = 153.0.8010.53`, version 26.917.62051 (bundle mtime 2026-09-23).
- **#11 transcript re-read** (`spike/macos-probe`, `probe-transcript.log` 1923–2024 s): the ChatGPT tree was
  7 nodes (`AXGroup×6, AXWindow×1`, no `AXWebArea`) and stayed 7 after walks and after setting
  `AXManualAccessibility` (reported `attributeUnsupported`, re-walked 3 s later: still 7). After setting
  `AXEnhancedUserInterface` (reported `notImplemented`) the next walk found 28 nodes incl. `AXWebArea`; the focused
  element resolved (`AXTextArea`) on the first `id` after two walks. RESULTS §4 attributed the wake to the walk and
  declared both attributes "rejected and unnecessary" from their return codes — which the same report calls
  untrustworthy for setters. Production ported the walk only. It "worked" in #11 because the probe had set the
  attribute earlier in that process's lifetime.

## Ranked hypotheses (each with its prediction)
1. **H1 — the app's web tree is off until an AX client sets `AXEnhancedUserInterface` on the application
   element** (the undocumented VoiceOver signal Chromium listens for). Predicts: walks alone
   never exceed the native shell; after the set, a walk shows `AXWebArea` and focus resolves; stays on for
   the process lifetime (a later press resolves with no wake).
2. **H2 — `AXManualAccessibility` (Electron's own switch) does the same, possibly with a delay** (#11 re-walked
   only 3 s after it). Predicts: the tree wakes after the Manual set alone at some checkpoint ≤ 3 s.
3. **H3 — after enabling, focus needs a walk and/or time** (#11: `id` 2 s after the set still `-25212`, success
   only after walks). Predicts: a read right after the set fails; read after walk (or +delay) succeeds.
4. **H4 — application-element `AXFocusedUIElement` answers where system-wide does not.** Predicts: the app-level
   read succeeds at a stage where system-wide still returns `-25212`.
5. **H5 — wake-walk size/timing alone** (the brief's starting point). Already contradicted by #11 (7 nodes,
   queue empty) and #14 (every press walked); predicts success after a larger walk or a delay without any set.

## Diagnostic (temporary): `JevPaste --diagnose-focus`
A launch flag like `--probe`: a separate delegate that registers ⌘⇧V and runs the stages below instead of a Paste
Attempt — **nothing is inserted, the clipboard is untouched**. Logger subsystem `jevpaste`, category
`FocusDiagnostic`; status-item title shows the stage that first resolved (`D:S2` etc., `D:none`).
Logged per line: stage, `sw=<AXError>`, `app=<AXError>`, `win=<AXError>`, found role/subrole,
`selectedTextRangeSettable`, set-status, walk `visited`/`queueLeft`/`webAreas`/top-5 role counts. Never values,
titles or descriptions.
- **S0** reads only (sw, app-level, focused window); read-only values of both attributes.
- **S1** production walk (300 / 100 per element), read; +500 ms read. → H5.
- **S2** set `AXManualAccessibility=true`; checkpoints +0, +1 s, +3 s: read → walk → read. → H2, H3, H4.
- **S3** only if still unresolved: set `AXEnhancedUserInterface=true`; same checkpoints. → H1, H3, H4.
- A second press in the same app process runs S0 first → persistence.

## Live round (one `ask`)
Quit the installed JevPaste; Daniel quits and reopens ChatGPT (fresh process = attributes unset); clicks into a
throwaway chat's composer; one ⌘⇧V; waits ~8 s; second ⌘⇧V. Control: one ⌘⇧V in a Chrome `data:` textarea.
Then relaunch the installed app. Verdict mapping: first stage that resolves = confirmed mechanism; stages before
it killed. H4 is confirmed only if `app=success` while `sw=-25212` at the same checkpoint.

## Fix direction (after confirmation, app-agnostic)
In `AXFocusSource`: on `noValue`, tell the frontmost application element an assistive client is present (the
confirmed attribute), then walk and retry within a bounded budget. Keyed on the failure, never on a bundle id;
attributes an app does not implement cost one IPC. Side effects of `AXEnhancedUserInterface` (known to disturb
window animation in some apps) are weighed at GATE B2 if H1 wins over H2.
