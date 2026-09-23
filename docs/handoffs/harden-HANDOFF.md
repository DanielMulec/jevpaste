# Handoff — harden (issue #28: Harden installation and daily use)

Worktree `~/.pi/worktrees/jevpaste/harden`, branch `harden`, forked from `main` a6a639d. Pushed, **not merged**.
Ticket [Harden installation and daily use](https://github.com/DanielMulec/jevpaste/issues/28) · Design
`docs/design/hardening.md` (GATE A approved) · Brief `docs/briefs/harden-brief.md`. Supervisor `01a0cf8d`.
`make check` green: 294 tests in 53 suites + `hook-test` (6 cases).

## 1. Commits
| sha | what |
|---|---|
| 6c1ec3a | design doc |
| 6f318d8 | `TargetAppFocusReturn` poll captures `self` strongly (item 9); lone-`\r` test (item 10, passed at once — no fix) |
| eccab43 | `OutcomeMessage.logName(for:)` → `outcome refused.noEditableTarget` (item 8) |
| fda6cb6 | comment: "History read failed" unreachable until the history UI (item 11) |
| 5b4176d | `HistoryNoticeSurface` → `IndicatorNoticeSurface`, new `IndicatorNotice`; history notices = `IndicatorNotice(historyUnavailable:/historyRuntimeFailure:)` |
| 851ddb1 | **Core**: `PasteOutcomePresenter.showDelivering()`, called in `deliver()` after the Bound Target re-verification (approved at GATE A) |
| 879b2b6 | presenter: "Pasting…" (`arrow.down.doc`), no hint, click inert — only over processing/retrying (item 6) |
| 4337e0c | `AccessibilityGrantCheck` + `GrantCheckingHotkey` (item 1); MacInterop `HotKeyRegistrar` returns `OSStatus`, `GlobalHotkey(onRegistrationFailure:)`, `HotkeyRegistrationReport` (item 5) |
| 9f92630 | `LoginItemToggle` / `LoginItemMenu` / `MainAppLoginItemService` — "Open at Login" (item 2) |
| 91ba4c9 | `docs/signing.md` rotation section (item 4) |
| 7d520ce | `scripts/check-staged-snapshot.sh`, `scripts/test-staged-snapshot.sh` (`make hook-test`, step 8), line guard fallback, new hook (item 3) |
| ef9092d | design doc names the hook-test step (first commit through the new hook) |

## 2. Architecture and why
- **Notices** (`Indicator/IndicatorNotice.swift`, `IndicatorNoticeSurface.swift`): one generic warning line
  (content + duration) through the existing decorator — shown when the presenter is idle, else waits (newest only).
  Why generalise instead of a second decorator: one indicator, one arbitration rule for all non-attempt notices.
- **Grant check** (`Launch/AccessibilityGrantCheck.swift`): `AccessibilityTrust` seam (prod `AXIsProcessTrusted()`,
  never prompting). Launch: log `grant check at launch trusted=…`, notice 8 s if false. `GrantCheckingHotkey`
  decorates the `Hotkey` port: every ⌘⇧V re-checks; untrusted → notice 5 s and **no Paste Attempt** (the attempt
  would refuse "No text field focused", which is misleading). No polling. Runs after history opening, so the grant
  notice wins over a history notice at launch.
- **Hotkey failure**: Carbon status of `InstallEventHandler`/`RegisterEventHotKey` returned by the registrar;
  `GlobalHotkey` reports non-zero once; root logs + notice 8 s. AdapterProbe keeps the silent default.
- **Delivery wording**: Core owns the phase, the port already mirrors processing/retrying, so `showDelivering()`
  is the missing phase event (the shell has no other signal; an `Inserter` decorator was rejected as indirect).
  Hidden (delivery before 150 ms or after the chooser) stays hidden; an earlier outcome keeps its auto-hide.
- **Open at Login**: the system is the only store; `menuState` is read from `SMAppService.mainApp.status` on every
  `menuNeedsUpdate`. `.requiresApproval` = mixed state + title suffix; click opens Login Items settings.
  Errors → log (`NSError.code`) + notice "Open at Login could not be changed". `SmartPasteApplication.loginItem`
  is exposed so `MenuBarDelegate` builds the menu after the root (notices share the indicator).
- **Staged snapshot**: see `docs/quality-gate.md` § Staged snapshot (checkout-index → rsync by content into
  `$(git rev-parse --absolute-git-dir)/staged-snapshot`, `.build`/`build`/`node_modules` excluded, then `make check`
  with a clean git env). Hook runs the **working tree's** copy of the script; checkouts without it run plain
  `make check` in place. Timing: first commit per worktree ≈ 56 s (package resolve + full build), later ≈ 10–16 s.
- **Declined at GATE A** (item 7): no URLSession pre-warm (only helps a paste within the idle timeout after launch;
  cold 1.3 s fits the 5 s clock); no cancel token (needs a Core port change; Core already ignores stale replies;
  saves one free-tier call per cancel).

## 3. Review findings
Not yet reviewed: the GPT-6-Sol pre-merge review comes next. The supervisor read the Core delivery diff and the
snapshot script at GATE B and raised no findings.

## 4. Merge touchpoints
- `main` gained cc556cc after the fork. `git diff harden...origin/main` shows one added file,
  `docs/briefs/multiline-probe-brief.md`; the supervisor mentioned two brief files, so re-check at merge. No
  overlap with this branch.
- Any branch implementing `PasteOutcomePresenter` must add `showDelivering()` (only `IndicatorPresenter` and Core's
  `FakePresenter` today).
- Renames: `HistoryNoticeSurface` → `IndicatorNoticeSurface`, `HistoryNotice` → `IndicatorNotice` (+History
  extension). The history UI branch ([Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27))
  must use the new names; `IndicatorNotice(historyRuntimeFailure:)` for `items()` failures.
- `SmartPasteApplication` / `MenuBarDelegate`: menu now built after the root; new menu items go into
  `MenuBarDelegate.makeMenu(loginItem:)`.
- Shared `.git/hooks/pre-commit` is already the new one (installed from this branch). Until merge, other
  worktrees fall back to in-place `make check`.

## 5. Open questions / live gaps
- Live, all passed on ef9092d:
  - **L1**: the log shows `grant check at launch trusted=true` and Daniel saw no notice.
  - **L3**: the log runs 21:20:19.556 `processing indicator shown` → 21:20:20.430 `cancel clicked` →
    `outcome cancelled`; Daniel saw "Cancelled" and nothing was inserted.
  - **L2**: the log shows `login item status enabled`; `sfltool dumpbtm` shows `2.com.jevpaste.JevPaste` as
    [enabled, allowed, notified]; the ✓ was there after relaunch. Left **on**, as Daniel prefers.
- **Owner-deferred (out of scope, do not implement):** Daniel would prefer "Open at Login" to disappear once the
  app is registered in macOS Login Items, and reappear only if it is removed there.
- "Pasting…" not seen live: Jev did not answer during L3, because the attempt was cancelled first.
- Hotkey registration failure not forced live (would need another app holding ⌘⇧V).
- `.requiresApproval` path of Open at Login not seen live unless macOS asks for approval.
- Pre-warm / cancel token declined — revisit only if cold first-paste latency or cancelled-call cost matters.
- Signing rotation steps are written, not executed (a real rotation drops Daniel's grant).

## 6. Do not
- Merge, or `make install` without the supervisor's go (the app is shared with probe/prototype workers).
- Prompt for Accessibility (`AXIsProcessTrustedWithOptions` with prompt) — stale rows make the prompt misleading.
- Store Open-at-Login state ourselves; read `SMAppService` status.
- Let `rsync` delete the snapshot's `.build`/`node_modules`, or run a real `make check` inside `hook-test`.
- Print `~/.config/jevpaste/env`; put clipboard/Candidate text in logs.

## Suggested skills
- `~/.agents/skills/tdd/SKILL.md` — every change here went red first (mutation for the snapshot script).
- `~/.agents/skills/codebase-design/SKILL.md` — the `showDelivering` seam and notice generalisation.
- `~/.agents/skills/code-review/SKILL.md` — self-check `git diff main...harden` against the brief.
- `pi-intercom` skill — supervisor `01a0cf8d`: `send` per step, `ask` at gates and before `make install`.
