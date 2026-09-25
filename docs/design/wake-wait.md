# Wake Wait — one press while the Target app's focus is unreadable

Slice: [Implement the Wake Wait](https://github.com/DanielMulec/jevpaste/issues/43). Contract: the ten settled points of
[Don't wake the target app for a Direct Paste](https://github.com/DanielMulec/jevpaste/issues/36#issuecomment-5838246196).
Replaces the refusal half of [chatgpt-resolver.md](chatgpt-resolver.md). Live: `run-2026-09-25-wake-wait.log`.

## Gate A numbers (`docs/acceptance/run-2026-09-25-wake-wait-gate-a.log`, installed throwaway probe, 20 ms re-reads)
- Fresh Chrome `data:` tab, trigger the moment Chrome is frontmost, 8/8: first system-wide read `-25212` (no value),
  readable on the 3rd read at **41–48 ms** (median 44.5), role `AXTextArea`. Plain re-reading — no walk, no switch.
- `AXEnhancedUserInterface` was already `true` in Chrome before every run (set by another client; Chrome was not
  relaunched), so "without the switch" is unmeasurable; setting it again changed nothing (41/45/44 ms). Settled tab: 0 ms.
  ChatGPT app (#33 live rounds): the switch is required, then the focus resolves 1–3 s later without a walk.
- ⇒ Minimum: **re-read on a timer, keep the one-shot switch, drop the 300-node wake walk** (killed in #33; costly per read).

## Core — phase `wakeWaiting`, before the Bound Target
| phase | event | action → next phase |
|---|---|---|
| idle | ⌘⇧V, Active Item, resolver `.focusUnreadable(app)` | note start; 150 ms → `showWaking(applicationName:onCancel:)`; poll in 50 ms → wakeWaiting |
| wakeWaiting | poll: `.resolved(t)` | unchanged flow from the Pre-checks (Direct Paste / Jev); outcome carries `wakeWait` |
| wakeWaiting | poll: `.noEditableTarget` | `.refused(.noEditableTarget)` with `wakeWait` → idle |
| wakeWaiting | poll: still unreadable, `now − start ≥ wakeWaitLimit` (3 s) | `.refused(.targetNotReady(applicationName:))` → idle, no Jev |
| wakeWaiting | click on the indicator | `.cancelled` → idle, nothing written, no Jev |
| wakeWaiting | ⌘⇧V | ignored, as in every running phase |
- **Poll interval 50 ms**: Chrome's ~45 ms settles on the 1st–2nd re-read, well before the 150 ms indicator (no
  flash); ≤ 60 reads over 3 s; worst-case added latency 50 ms. The last read happens at the limit, not after it.
- **Clock rule**: the 5 s Jev deadline is `now + 5 s` at resolution (`askJev` runs then). A wait that already showed
  the indicator switches it to "Jev is choosing…" at once; otherwise the 150 ms indicator timer starts at resolution.
  Direct Paste after a shown wait turns "Waking…" into "Pasting…" (`showDelivering`).
- State: `WakeWait { start: AttemptStart { number, item, pressedAt, wakeWait, isIndicatorShown }, applicationName }`
  beside `RunningAttempt` (no target yet); timers moved to the coordinator; the number carries over, so stale reads
  and clicks are dropped as today. `RunningAttempt.wakeWait: Duration?`.

## MacInterop — `TargetResolution.focusUnreadable(applicationName:)` (was `.waking`)
- Focus unreadable + a frontmost app → `.focusUnreadable(name)` always; no frontmost app → `.noEditableTarget`.
  `.noEditableTarget` otherwise only for a readable, non-editable focus.
- One-shot switch: the first unreadable read of a process checks its `AXEnhancedUserInterface` and sets it if `false`,
  once per process — an app that ignores it is not asked every 50 ms. The pid set is never pruned: one Int32 per app
  process that was ever unreadable; a recycled pid would skip the check (a reused pid of a sleeping Electron app is the
  only cost: it refuses until JevPaste restarts). Log `focus unreadable app=<bundle> enhancedUI=` once per process.
- **The 5 s per-pid window is removed**: it only kept saying "waking" across presses; the wait now spans the readiness.

## Presenter seam — one new method, one extra argument
- `showWaking(applicationName:onCancel:)`: the processing mechanism (same panel, symbol, click cancels), text
  `Waking <App>… click to cancel`. `showDelivering` turns it into "Pasting…" like processing.
- `showOutcome(_:note:path:wakeWait:)` (app tests' old calls: a test-target overload with `nil`). Log, whole ms:
  `outcome inserted via=directPaste wakeWait=312`; no key when the attempt did not wait.
- **Esc**: click only, as on the processing indicator (Gate A): a key indicator would move focus off the very element
  whose readability the attempt waits for. `CONTEXT.md` now says "a click on the indicator cancels".
- Refusal: `PreCheckRefusal.targetNotReady(applicationName:)`, text `<App> isn't ready — press ⌘⇧V again`, log
  `refused.targetNotReady`.

## Tests
Core (`WakeWaitTests`, `FakeTargetResolver` answers unreadable N times then resolved): resolves on the 2nd poll →
Jev asked, deadline = resolution + 5 s (times out at 5 s after it, not before); never resolves → refusal at 3 s
(not at 2.95 s), no Jev call; click mid-wait → `.cancelled`, no Jev, nothing written; later polls dropped; readable
at once → no wait, no indicator, `wakeWait` nil (regression); pre-check refusal after a wait; single-line Direct Paste
after a wait; the outcome carries the waited duration; indicator "Waking" at 150 ms, not before, not when resolved
sooner; ⌘⇧V during the wait ignored. MacInterop (`AccessibilityWakeTests` rewritten through `FakeFocusSource`):
unreadable in any app → focusUnreadable; switch set once when off, never when on; no frontmost → noEditableTarget;
readable non-editable → noEditableTarget. App: wording + log name (`OutcomeMessageTests`), waking indicator and click
cancel (`IndicatorPresenterTests`), `wakeWait=` fragment present/absent (log-line tests).

## Live run (after the install gate)
a. Fresh Chrome `data:` tab, textarea focused, SIGUSR1 at once, 3× → one press pastes; log `wakeWait=<ms>` (or no key
   when Chrome was readable at once). Why: the case that refused on 2026-09-25 now pastes on one press.
b. Herdr shell prompt → value at the prompt, not executed, no `wakeWait=` key, then `C-c`. Why: readable targets never wait.
c. After-limit refusal: Finder desktop (nothing focused, `-25212` for good) → "Finder isn't ready" after 3 s,
   `wakeWait=3000`; record which common no-focus surfaces now wait 3 s (settled point 3's daily cost).
d. Daniel: quit + relaunch ChatGPT, click the composer, ⌘⇧V once → value lands, no "press again". Why: the cold
   Electron case, one press. The log is the proof (his menu bar auto-hides).
