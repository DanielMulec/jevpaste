# Handoff — jevpaste (v1 map closed; plain issues for refinements; "other users" map not yet charted)

Written 2026-09-27 ~13:00 for a fresh session. **Model:** Daniel runs the orchestrator on `claude-fable-5-1` (medium)
— check `env | grep '^PI_'` and say which you are. Repo: `/Users/danielmulec/Projekte/experiments/jevpaste` (public,
`DanielMulec/jevpaste`, **no licence**; `main` @ `48e659b` + this handoff, tree clean apart from untracked `.vscode/`).
Owner: Daniel Mulec. Tracker: GitHub Issues (`gh` authenticated; native sub-issues + blocking via GraphQL
`addSubIssue`/`addBlockedBy`, header `GraphQL-Features: sub_issues,issue_dependencies`). Your intercom id:
`echo $PI_INTERCOM_SESSION_ID`.

## What changed this session (process, not code)
- **The v1 map is closed**: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1)
  — destination reached 2026-09-24; it had been kept open as a "v1.x backlog", which wayfinder's scope rules don't
  allow (out-of-scope work returns only under a redrawn destination, as a fresh effort). Daniel: "we should absolutely
  close the map then and chart v1.x". Its body still holds every decision (Decisions so far) and the glossary lives in
  `CONTEXT.md` — read those, don't re-derive.
- **Two tracks from now on** (Daniel agreed; the router is `~/.agents/skills/ask-matt/SKILL.md`, user-invoked, read it):
  1. **Daily-use refinements = plain issues**, label `triage` → `/grill-with-docs` (grilling with CONTEXT.md/ADR
     paper trail) → `/implement` (worker slice as before). Label `parked` = known gap deliberately left until real use
     demands it. Bugs → `/diagnosing-bugs`. Refactors → `/improve-codebase-architecture` produces the candidate → issue.
     Rule of thumb: **sharp question → plain issue; foggy cluster → map.**
  2. **"Other users from the public repo" = a new wayfinder map, not yet charted.** Cluster: product name (keep the
     Jev/Jevons shoutout; whether "Jev" may appear at all is a Typesafe brand-terms question → research first; "Jevons
     Paste" reads possessive), public website (jaste.app-style), **licence** (public but unlicensed → not open
     source), onboarding (first child: issue 55), publication hygiene. Chart it only when Daniel is up for a grilling
     session: name the destination first, then breadth-first; it's HITL work.

## Open issues (none claimed, no map)
- `triage`: [Decide what the secure-field pre-check uses when the OS secure-input flag is absent](https://github.com/DanielMulec/jevpaste/issues/38)
  (Herdr `sudo` prompt not detected), [Improve Narrowing after the beta](https://github.com/DanielMulec/jevpaste/issues/52)
  (wait for Daniel's daily-use evidence), [Screen a copied API key that is not (yet) stored out of history](https://github.com/DanielMulec/jevpaste/issues/56),
  [Open Settings on first launch when no Jev Provider has a key](https://github.com/DanielMulec/jevpaste/issues/55)
  (onboarding — belongs to the future map, triage-labelled meanwhile).
- `parked`: [Copies too big for one Jev call](https://github.com/DanielMulec/jevpaste/issues/57).

## Installed app
`~/Applications/JevPaste.app` = `main` @ `af8d0b6`, running, both key files present
(`~/.config/jevpaste/keys/<provider>`), Accessibility grant trusted. Provider = Vercel AI Gateway. Live suites:
`JEVPASTE_LIVE_JEV=1 make test` (never prints keys). Optional leftover: stale Keychain item
`com.jevpaste.JevPaste.jev-provider-key` from the first Keychain build; the app ignores it.

## Build protocol (unchanged, worked well)
- Worker: fresh Opus 5.5 **medium** in a Herdr tab per slice (`herdr tab create --cwd <worktree> --label <name>
  --no-focus`, `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model
  anthropic/claude-opus-5-5:medium`, `herdr agent prompt`). Brief in `docs/briefs/<slice>-brief.md` on `main`
  (pattern: `typesafe-direct-brief.md`), Gate A (design) → Gate B (diff read by you) → install + Daniel's live block
  relayed by you → Gate C (run log + report comment).
- Review: fresh **`openai-codex/gpt-5.6-sol:medium`** (not 6-Sol), detached worktree at the branch head,
  `REVIEW-BRIEF.md` with five specific questions and VERDICT/BLOCKING/NON-BLOCKING/DUPLICATION/GAPS/METHOD, mandatory
  `intercom send <your-id>` last. Reviewer sessions end after their verdict — start a fresh one for the delta review
  with the prior REVIEW.md as context. Then `git merge --no-ff origin/<branch>` on `main`, `make check`, push,
  `make install`, quit the old app by pid, `open ~/Applications/JevPaste.app --args --accept-signal-trigger`, resolution
  comment, close, tab + worktree cleanup, branch delete (local + origin).
- Daniel's live steps: numbered block in plain words; relay his verbatim results to the worker; the worker reconciles
  every step from the log/DB (`JEVPASTE-…` rows only) — never trust words alone.
- **Check the tab id before `herdr tab close`** (a predecessor closed the wrong tab).

## Standing rules (from the closed map's Notes — still binding)
- Jev-first: everything that can be a Jev choice is a Jev choice; no local gates/classifiers by default. Paste Result
  = one exact, contiguous, verbatim excerpt of the Active Item — never authored text.
- Code quality over speed; 400 lines per file absolute; `make check` is the gate; fresh-instance semantic-duplication
  review before every merge. No hosted CI.
- You orchestrate; workers build. Orchestrator latitude: read code, probe cheaply, merge + `make check`, install,
  tracker upkeep, kill runaways — without asking. Product decisions go to Daniel as short numbered questions with a
  recommendation each; he answers "B2: 1" style — repeat the mapping in your reply.
- Never print `~/.config/jevpaste/env`, `~/.config/jevpaste/keys/*`, a key's length or prefix, or history rows other
  than `JEVPASTE-…`. Committed logs carry no literal text, no window titles, no `/Users/<name>` paths.
- Restore the clipboard vault before relaunching the app (Launch Adoption). Signals by pid only.
- Chrome DevTools MCP: own tabs, re-list before `close_page`; the "Allow remote debugging?" sheet is Daniel's.
- Daniel writes from the laptop (screenshots in `~/Desktop/Bildschirmfoto …png`); phone instructions only for
  Telegram-originated messages.
- Any new text field: `usesSingleLineMode`, `wraps = false`, `isScrollable`, red-first layout test. Show/Hide on a
  secure field must not fire end-edit side effects.
- Handoff lives in `docs/HANDOFF.md`, written before ~200k context.
