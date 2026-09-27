# Handoff — jevpaste (Opaque Token shipped; plain issues only; "other users" map not yet charted)

Written 2026-09-27 ~20:45 for a fresh session. **Model:** Daniel runs the orchestrator on `claude-fable-5-1` (medium)
— check `env | grep '^PI_'` and say which you are. Repo: `/Users/danielmulec/Projekte/experiments/jevpaste` (public,
`DanielMulec/jevpaste`, **no licence**; `main` @ `4b6bc33` + this handoff, tree clean apart from untracked `.vscode/`).
Owner: Daniel Mulec. Tracker: GitHub Issues (`gh` authenticated; native sub-issues + blocking via GraphQL
`addSubIssue`/`addBlockedBy`, header `GraphQL-Features: sub_issues,issue_dependencies`). Your intercom id:
`echo $PI_INTERCOM_SESSION_ID`. Router for the skills: `~/.agents/skills/ask-matt/SKILL.md` (read it once).

## What happened this session
- **Decided and closed** [Decide what the secure-field pre-check uses when the OS secure-input flag is absent](https://github.com/DanielMulec/jevpaste/issues/38):
  keep the two OS signals, document the Herdr-nested `sudo` gap. Daniel leans toward *removing* the check later
  ("either do it well or drop it"; utility to a human is marginal) → parked as
  [Consider removing the secure-field pre-check altogether](https://github.com/DanielMulec/jevpaste/issues/58).
- **Grilled, built, reviewed, merged, installed** [Refuse any copied API key at ⌘⇧V, whatever its vendor (Opaque Token rule)](https://github.com/DanielMulec/jevpaste/issues/56)
  (was mis-titled as a history issue; Daniel's real concern: *any* API key must never be sent to Jev). Decision in
  the issue body; resolution comment has the built shape, reviews, revert path. Key facts:
  - `SuspectedSecretRules.anywhere` (11 rules, screens Target Context) and `standard = anywhere + [.opaqueToken]`
    (refuses the Active Item). **Item-only** was Daniel's call after the round-1 review (B1). Revert = delete that
    one entry, or `git revert -m 1 4b6bc33`, or tag `pre-opaque-token` (+ `make install`).
  - Rule: trimmed whole text, ≥16 bytes, `[A-Za-z0-9_-]`, ≥1 letter **and ≥1 digit** (digit requirement added at
    Gate A: identifiers/branch names/hyphenated words are common copies). Plus prefix rules `vck_`, `sk_test_`.
  - `CONTEXT.md` gained **Suspected Secret** and **Opaque Token**. `docs/design/pre-checks.md` has the table + the
    whole-text paragraph. Live proof `docs/acceptance/run-2026-09-27-opaque-token.log`.
- Filed [Log which suspected-secret rule refused a Paste Attempt](https://github.com/DanielMulec/jevpaste/issues/59)
  (`triage`, small): the log says only `refused.suspectedSecret`; worker's option A is written in the body.

## Open issues (none claimed, no map)
- `triage`: [Improve Narrowing after the beta](https://github.com/DanielMulec/jevpaste/issues/52) (hold — wait for
  Daniel's daily-use evidence), [Open Settings on first launch when no Jev Provider has a key](https://github.com/DanielMulec/jevpaste/issues/55)
  (onboarding — belongs to the future map), [Log which suspected-secret rule refused a Paste Attempt](https://github.com/DanielMulec/jevpaste/issues/59).
- `parked`: [Copies too big for one Jev call](https://github.com/DanielMulec/jevpaste/issues/57),
  [Consider removing the secure-field pre-check altogether](https://github.com/DanielMulec/jevpaste/issues/58).

## Two tracks (unchanged)
1. **Daily-use refinements = plain issues**, `triage` → `/grill-with-docs` → `/implement` (worker slice, below).
   `parked` = deliberate gap. Bugs → `/diagnosing-bugs`. Rule of thumb: sharp question → plain issue; foggy cluster → map.
2. **"Other users from the public repo" = a new wayfinder map, not yet charted.** Cluster: product name (keep the
   Jev/Jevons shoutout; whether "Jev" may appear at all is a Typesafe brand-terms question → research first; Typesafe
   keys have **no documented format** — relevant to onboarding), public website, **licence** (public but unlicensed →
   not open source), onboarding (#55), publication hygiene. Chart only when Daniel is up for a HITL grilling session:
   destination first, then breadth-first.

## Installed app
`~/Applications/JevPaste.app` = `main` @ `4b6bc33`, running (pid 9202 at write time), both key files present
(`~/.config/jevpaste/keys/<provider>`), Accessibility grant trusted. Provider = Vercel AI Gateway. Live suites:
`JEVPASTE_LIVE_JEV=1 make test` (never prints keys).

## Build protocol (worked well again; two lessons added)
- Worker: fresh Opus 5.5 **medium** in a Herdr tab per slice (`herdr tab create --cwd <worktree> --label <name>
  --no-focus`, `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model
  anthropic/claude-opus-5-5:medium`, `herdr agent prompt`). Brief in `docs/briefs/<slice>-brief.md` on `main`
  (latest pattern: `opaque-token-brief.md`), Gate A (design) → Gate B (diff read by you) → install + Daniel's live block
  relayed by you → Gate C (run log + report comment).
- Review: fresh **`openai-codex/gpt-5.6-sol:medium`**, detached worktree at the branch head, untracked
  `REVIEW-BRIEF.md` there with five specific questions and VERDICT/BLOCKING/NON-BLOCKING/DUPLICATION/GAPS/METHOD,
  mandatory `intercom send <your-id>` last. Delta review = a **fresh** reviewer with the prior verdict quoted in its
  brief. Then `git merge --no-ff origin/<branch>` on `main`, `make check`, push, `make install`, quit the old app by
  pid, `open ~/Applications/JevPaste.app --args --accept-signal-trigger`, resolution comment, close, tab + worktree
  cleanup (`git worktree remove` **before** `git branch -d`), branch delete (local + origin).
- **Lessons:** (1) the app log does not name the matching secret rule (see #59) — don't promise `rule=…` evidence
  in a brief; (2) the worker's Pi session had **0 MCP servers** (pi-mcp-adapter wants `~/.pi/agent/mcp.json` renamed
  to `mcp-adapter.json` — Daniel's global config, not touched); the worker opened its Chrome tab via **AppleScript**
  (`open location "data:…"`, closed by URL) — fine as the default for live-proof pages.
- Daniel's live steps: numbered block in plain words; relay his verbatim results to the worker; the worker reconciles
  every step from the log/DB (`JEVPASTE-…` rows only) — never trust words alone.
- **Check the tab id before `herdr tab close`.** Herdr may create tabs in another workspace (`wB` vs `wC`); harmless.

## Standing rules (from the closed v1 map's Notes — still binding)
- Jev-first: everything that can be a Jev choice is a Jev choice; local rules only where *sending* is the harm
  (secrets). Paste Result = one exact, contiguous, verbatim excerpt of the Active Item — never authored text.
- Code quality over speed; 400 lines per file absolute; `make check` is the gate; fresh-instance semantic-duplication
  review before every merge. No hosted CI.
- You orchestrate; workers build. Orchestrator latitude: read code, probe cheaply, merge + `make check`, install,
  tracker upkeep, kill runaways — without asking. Product decisions go to Daniel as short numbered questions with a
  recommendation each; he answers "Q1: 1" style — repeat the mapping in your reply. When he says "I have to trust
  you", decide and say what you decided.
- Never print `~/.config/jevpaste/env`, `~/.config/jevpaste/keys/*`, a key's length or prefix, or history rows other
  than `JEVPASTE-…`. Committed logs carry no literal text, no window titles, no `/Users/<name>` paths.
- Restore the clipboard vault before relaunching the app (Launch Adoption). Signals by pid only.
- Chrome DevTools MCP (orchestrator side): own tabs, re-list before `close_page`; the "Allow remote debugging?" sheet
  is Daniel's.
- Daniel writes from the laptop (screenshots in `~/Desktop/Bildschirmfoto …png`); phone instructions only for
  Telegram-originated messages.
- Any new text field: `usesSingleLineMode`, `wraps = false`, `isScrollable`, red-first layout test.
- Handoff lives in `docs/HANDOFF.md`, written before ~200k context.

## Suggested skills for the next session
- `ask-matt` (router), then per track: `grill-with-docs` (+ `grilling`, `domain-modeling`) for #59 or any `triage`
  issue; `implement` for the worker brief; `code-review` is the in-repo GPT review above; `wayfinder` only for the
  "other users" map; `research` first for the Typesafe brand-terms question.
