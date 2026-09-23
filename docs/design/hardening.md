# Hardening — installation and daily use

Slice: [Harden installation and daily use](https://github.com/DanielMulec/jevpaste/issues/28) (body + inherited
list). Shell = `Sources/JevPasteApp`. Everything visible goes through the one indicator; notices use the existing
wait-while-a-Paste-Attempt-shows mechanism of `HistoryNoticeSurface`, generalised to `IndicatorNoticeSurface` +
`IndicatorNotice` (content, duration; the history notices become `IndicatorNotice(historyUnavailable:)` etc.).

## Items → mechanism, visible form, proof
| # | item | mechanism | visible form | unit-tested | live |
|---|---|---|---|---|---|
| 1 | grant self-check | `AccessibilityGrantCheck` over an `AccessibilityTrust` seam (prod `AXIsProcessTrusted()`, never prompting). Runs at launch; logs `grant check trusted=…` every run. `GrantCheckingHotkey` decorates the `Hotkey` port: each ⌘⇧V re-checks first | notice "No Accessibility access — turn JevPaste off and on in Settings › Privacy › Accessibility" 8 s at launch, 5 s on ⌘⇧V | notice at launch iff untrusted; ⌘⇧V untrusted → notice, press not forwarded; trusted → forwarded; grant regained → logged once | L1 |
| 2 | launch at login | `LoginItemToggle` over a `LoginItemService` seam (prod `SMAppService.mainApp`). Menu state read from the system's `status` on every menu open (`menuNeedsUpdate`) — the system persists it, we store nothing | menu item "Open at Login" with ✓; `.requiresApproval` → mixed state, click opens Login Items settings; register/unregister error → logged + notice "Open at Login could not be changed" | status → menu state; click → register/unregister; error → notice | L2 |
| 3 | staged snapshot | hook runs `scripts/check-staged-snapshot.sh`: `git checkout-index -a` into a temp dir, `rsync --checksum --delete` into a persistent snapshot `$(git rev-parse --git-dir)/staged-snapshot` (keeps `.build`, `node_modules` symlinked → incremental), runs `make check` there. `check-line-counts.sh` falls back to `find` outside a git work tree | hook output names the snapshot dir | scripted scenario `scripts/test-staged-snapshot.sh` (temp repo, stub check command): staged good + dirty bad → pass; staged bad + clean good → fail; untracked excluded; staged deletion absent | commit on this branch |
| 4 | signing rotation | `docs/signing.md` section: when, re-create cert, re-sign, TCC migration (reset + re-grant), verify DR/`AXIsProcessTrusted`/log | doc | — | — |
| 5 | hotkey failure | `HotKeyRegistrar.registerCommandShiftV` returns the `OSStatus`; `GlobalHotkey(onRegistrationFailure:)` (MacInterop) reports it; root shows a notice | notice "⌘⇧V unavailable — another app uses it; quit that app, then relaunch JevPaste" 8 s; logged with status | MacInterop: failure reported once, success silent; shell: notice text | not forced live |
| 6 | delivery wording | Core port gains `showDelivering()`, called in `deliver()` after the Bound Target re-verification (**Core change — asked here**). Presenter: if processing/retrying is shown → "Pasting…" (`arrow.down.doc`), no hint, click inert; if hidden → stays hidden | "Pasting…" for ≤ 150 ms | Core: called once before ⌘V; shell: wording, click ignored, hidden stays hidden | L3 sees it only if slow |
| 7 | pre-warm / cancel | **proposed: neither** (see decisions) | — | — | — |
| 8 | outcome log | `OutcomeMessage.logName` → `refused.noEditableTarget`, `failed.timedOut`, `inserted` | log only | one parametrised test | L1–L3 logs |
| 9 | focus-return weak self | poll captures `self` strongly: the chain is bounded (≤ 1 s, ~100 polls) and the clock drops each action after it fires, so no cycle outlives it | — | new test: focus return released mid-poll still completes | — |
| 10 | lone `\r` | test in `ChooserContentTests` (`"a\rb"` → "a … 2 lines"); fix only if red | — | yes | — |
| 11 | history read failed | verified: `items()` has no caller in the app today; comment at `IndicatorNotice(historyRuntimeFailure:)` pointing at [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27); nothing removed | — | existing test | — |

## GATE A decisions
1. **Grant re-check rule**: at launch and on every ⌘⇧V (no polling); while untrusted, ⌘⇧V shows the grant notice
   instead of starting a Paste Attempt (which would otherwise refuse misleadingly as "No text field focused").
2. **Launch at login**: menu "Open at Login" (✓ = enabled, mixed = needs approval), state always read from
   `SMAppService.mainApp.status`, default off, nothing stored by us.
7. **Pre-warm / cancel: neither.** A launch pre-warm only helps a paste within the connection's idle timeout
   (seconds–minutes after launch); cold 1.3 s is inside the 5 s clock. Cancelling the in-flight request saves one
   free-tier call per cancel, but needs a Core port change and Core already ignores stale replies. Recorded as
   open questions in the handoff.
9. **Focus return**: made structurally safe (strong capture in the bounded poll) rather than documented.
- Also asked: item 6 needs the one-method Core port change above (alternative without Core: a shell decorator on
  the `Inserter` port that tells the presenter at `postPasteKeystroke` — indirect, not recommended).
- Hook test (item 3): proposed wired into `make check` as step 8 `hook-test` (≈ 1 s, offline); else manual.
- Installing the new hook rewrites the **shared** `.git/hooks/pre-commit` (all worktrees). The new hook falls back
  to plain `make check` in a checkout without the snapshot script, so main/other branches behave as today.

## Live-run plan (each gated; batched into one ask where Daniel is needed)
- L1: `make install`, launch; `log show --last 5m --predicate 'subsystem == "jevpaste"'` shows
  `grant check trusted=true` and no notice appears (Daniel glances once).
- L2: Daniel opens the menu → "Open at Login" off; clicks it → `sfltool dumpbtm`/`SMAppService` status enabled
  (log line `login item status enabled`); quit + relaunch → menu shows ✓; click again to leave it as Daniel wants.
- L3: slow-Jev not forceable, so: Daniel copies the synthetic signature, ⌘⇧V in a Chrome textarea and clicks the
  indicator while "Jev is choosing… click to cancel" shows → "Cancelled", nothing inserted; log `cancel clicked`,
  `outcome cancelled`. Done as the first paste after the L1 launch (cold connection ≈ 1.3 s, the widest
  click window); if Jev answers first, repeat after a few minutes idle.
