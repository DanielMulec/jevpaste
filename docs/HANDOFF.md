# Handoff — jevpaste orchestrator (v1.x backlog; menu/Settings and Typesafe direct merged, nothing in flight)

Written 2026-09-27 ~12:45 for a fresh orchestrator session. **Model:** Daniel runs the orchestrator on
`claude-fable-5-1` (medium) — check `env | grep '^PI_'` and say which you are. Repo:
`/Users/danielmulec/Projekte/experiments/jevpaste` (public, `DanielMulec/jevpaste`, no licence; `main` @ `af8d0b6`
pushed, tree clean apart from untracked `.vscode/`). Owner: Daniel Mulec. Tracker: GitHub Issues with native
sub-issues + blocking (`gh` authenticated; wiring via GraphQL `addSubIssue`/`addBlockedBy`, header
`GraphQL-Features: sub_issues,issue_dependencies`). Your intercom id: `echo $PI_INTERCOM_SESSION_ID` — it overrides
any id in a brief.

## Context (read, don't re-derive)
- Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1) — read
  the body. v1 was reached 2026-09-24; the map stays open for the v1.x backlog. Notes carry the standing rules
  (Jev-first, execution override, models, Chrome rights, Other users). Decisions so far ends with the two tickets
  closed this session.
- Glossary: `CONTEXT.md` (Jev Provider, History Search, Full History, Active Item, Paste Attempt, Narrowing).
- **Closed this session** (both merged, installed, reviewed):
  - [Implement the status-item menu with History Search and the Settings window](https://github.com/DanielMulec/jevpaste/issues/53#issuecomment-5854285929)
    — `main` @ `0dd7de3`. Keys in `~/.config/jevpaste/keys/<provider>` (files, not Keychain — self-signed identity
    prompts per rebuild; `KeychainJevKeyStore` kept unused). Core seam `CaptureExclusion`: a copy of a stored key is
    a concealed Active Item, never recorded.
  - [Add Typesafe direct as a Jev Provider](https://github.com/DanielMulec/jevpaste/issues/54#issuecomment-5855096938)
    — `main` @ `af8d0b6`. `JevEndpoint.of(_:)` provider table; both providers selectable; 14-cell live replay: 12
    identical, 2 near-tie cells flip on both providers (tolerated in the opt-in live test, fixture unchanged);
    Typesafe warm median 259 ms vs Gateway 480 ms. Key editing end purges history rows equal to the saved key.
- **Installed app** `~/Applications/JevPaste.app` = `main` @ `af8d0b6`, running (launched 12:37, both key files
  present, grant trusted). Provider = Vercel AI Gateway (Daniel's last choice); his Typesafe key is stored too.
  Live suites: `JEVPASTE_LIVE_JEV=1 make test` reads both key files (never prints them).

## State of the map
- **Nothing in flight, nothing claimed.** Every ticket inside the v1 timeline is closed.
- **Open children (all post-timeline, unclaimed, unblocked):**
  [Open Settings on first launch when no Jev Provider has a key](https://github.com/DanielMulec/jevpaste/issues/55)
  (grilling, onboarding — Notes say onboarding is out of the starting scope; confirm with Daniel before claiming),
  [Improve Narrowing after the beta](https://github.com/DanielMulec/jevpaste/issues/52) (grilling),
  [Decide what the secure-field pre-check uses when the OS secure-input flag is absent](https://github.com/DanielMulec/jevpaste/issues/38)
  (grilling).
- **Fog (Not yet specified):** copies too big for one Jev call; secret screening beyond stored keys (a key not yet
  stored — e.g. copied from a console before pasting into Settings — still lands in history until editing ends);
  public website + product name (Daniel wants the Jev/Jevons shoutout; "Jev" in a third-party product name depends
  on Typesafe's brand terms → research first; "Jevons Paste" reads as a possessive — not decided); publication
  hygiene incl. licence.
- **Optional leftover for Daniel:** the Keychain item from the first Keychain build still exists
  (`security find-generic-password -s com.jevpaste.JevPaste.jev-provider-key` exit 0); the app never touches it.

## How this session ran (protocol that worked)
- Worker: fresh Opus 5.5 **medium** in a Herdr tab per slice (`herdr tab create --cwd <worktree> --label <name>
  --no-focus`, `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model
  anthropic/claude-opus-5-5:medium`, `herdr agent prompt`). Brief in `docs/briefs/<slice>-brief.md` on `main`
  (pattern: `typesafe-direct-brief.md`), Gate A (design) → Gate B (diff read by you) → install + Daniel's live block
  relayed by you → Gate C (run log + report comment).
- Review: fresh **`openai-codex/gpt-5.6-sol:medium`** (Daniel, 2026-09-27: "GPT-6-Sol sucks compared to 5.6-Sol";
  the map Notes are updated), detached worktree at the branch head, `REVIEW-BRIEF.md` with five specific questions
  and VERDICT/BLOCKING/NON-BLOCKING/DUPLICATION/GAPS/METHOD, mandatory `intercom send <your-id>` last. Reviewer
  sessions **end after their verdict** (the tab reports `done` and `herdr agent prompt` fails) — start a **fresh**
  reviewer for the delta review with the prior REVIEW.md as context. Then `git merge --no-ff origin/<branch>` on
  `main`, `make check`, push, `make install`, quit the old app by pid, `open ~/Applications/JevPaste.app --args
  --accept-signal-trigger`, resolution comment, close, map gist, tab + worktree cleanup, branch delete (local +
  origin).
- Daniel's live steps: send him a numbered block in plain words, relay his verbatim results to the worker, let the
  worker reconcile every step from the log/DB (`JEVPASTE-…` rows only) — never trust words alone.

## Session lessons (2026-09-27)
- **Check the tab id before `herdr tab close`.** I closed the wrong tab (the finished worker's) while replacing a
  reviewer; nothing was lost because everything was pushed, but list → read the id → close, every time.
- A key copied *before* it is stored bypasses stored-key exclusion — it happened in the normal first-time flow
  (copy from console → paste into Settings). Fixed for the edit-end case; format-based screening is still fog.
- Long keys wrapped inside a one-line `NSSecureTextField` (only "••" visible) — Daniel spotted it from a screenshot.
  Any new text field: `usesSingleLineMode`, `wraps = false`, `isScrollable`, with a red-first layout test.
- Show/Hide on a secure field: swapping fields fires an end-edit; guard it or side effects (save/purge/log) fire.
- Jev is nondeterministic on near-tie cells (p ≈ 0.4–0.5): a strict live replay flips randomly on **both**
  providers. Tolerate the documented alternative for exactly those cells; never loosen the whole test.
- Daniel writes from the laptop (screenshots land in `~/Desktop/Bildschirmfoto …png`; read the newest with the
  image reader). Don't send phone-specific instructions unless the message came from Telegram.
- Wayfinder's one-ticket-per-session rule was overridden by Daniel ("got the typesafe api key ready") — fine when
  he asks explicitly and the orchestrator's context is light; say so when you do it.

## Standing rules (unchanged — see the map Notes and older handoffs in git history for detail)
- You orchestrate; workers build. Orchestrator latitude: read code, probe cheaply, merges + `make check`, installs,
  tracker upkeep, kill runaways — without asking. Product decisions go to Daniel as short numbered questions with a
  recommendation each; he answers "B2: 1" style — repeat the mapping in your reply.
- Wayfinder governs; refer to tickets by linked title; claim by assigning Daniel.
- Never print `~/.config/jevpaste/env`, `~/.config/jevpaste/keys/*`, a key's length or prefix, or history rows
  other than `JEVPASTE-…`. Committed logs carry no literal text, no window titles, no `/Users/<name>` paths.
- Restore the clipboard vault before relaunching the app (Launch Adoption). Signals by pid only.
- Chrome DevTools MCP: workers use own tabs, re-list before `close_page`; the "Allow remote debugging?" sheet is
  Daniel's to click.
- Handoff lives in `docs/HANDOFF.md`, written before ~200k context.
