# Handoff — jevpaste: build #61 then #60; Jev-prompting research and offline analysis done

Written 2026-10-02 ~23:55 for a fresh orchestrator session.

- **Model.** This session ran `anthropic/claude-opus-5-5` (xhigh). Check `env | grep '^PI_'` and say which model
  you are.
- **Repo.** `/Users/danielmulec/Projekte/experiments/jevpaste`: public, `DanielMulec/jevpaste`, **no licence**.
  `main` is at `aca98df` plus this handoff. Since `4b6bc33` it has changed only in docs. The tree is clean apart from
  an untracked `.vscode/`.
- **Owner:** Daniel Mulec.
- **Tracker:** GitHub Issues. `gh` is authenticated. Native sub-issues and blocking go through GraphQL
  `addSubIssue` / `addBlockedBy` with the header `GraphQL-Features: sub_issues,issue_dependencies`.
- **Your intercom id:** `echo $PI_INTERCOM_SESSION_ID`.
- **Skill router:** `~/.agents/skills/ask-matt/SKILL.md`. Read it once.

## Next: build [#61](https://github.com/DanielMulec/jevpaste/issues/61), then [#60](https://github.com/DanielMulec/jevpaste/issues/60)

Daniel decided both, and both issue bodies are agent-ready. They carry no label, the same pattern as #56. Build them
one after the other with the build protocol below: one brief, one worker and one branch per issue. Not in parallel:
both edit `docs/design/jev-gateway.md`.

1. **#61: break probability ties by document order** (Core, `Narrowing/FollowUp.swift`).
   - It affects latency only: which carried pieces get a speculative next step.
   - The offline analysis C(c) found exactly 3 recorded follow-ups whose speculated set changes: **B06 r0, N03 r0,
     N03 r1** (comment on #61). Check whether these are among the 14 cells `NarrowingReplayTests` replays. If they
     are, update those expectations deliberately and list them in the resolution.
   - No user-visible change. Install after the merge anyway.
2. **#60: Vercel AI Gateway, served from TypeSafe's servers only** (`JevGateway`).
   - Send `providerOptions.gateway.only: ["typesafe-ai"]` on the Gateway route only. Typesafe direct rejects unknown
     top-level fields with a 400, so nothing changes there.
   - Log `upstream=<finalProvider>`.
   - Fix the README "served by" row, and the `jev-gateway.md` table, which wrongly says the Gateway's model is pinned.
   - Two open points, to settle at the source: can the Gateway also pin `jev-1.13.0`? What does the Gateway return
     when no allowed upstream can serve?
   - Live proof: at least 20 Gateway calls, every one `upstream=typesafe-ai`. The worker can run them itself
     (`JEVPASTE_LIVE_JEV=1`).
   - **Daniel keeps both Jev Providers** (see Lessons). #60 only restricts the servers behind the Gateway.

After both: [Improve Narrowing after the beta](https://github.com/DanielMulec/jevpaste/issues/52) stays `triage` and
on hold until Daniel's daily-use misses arrive.

## What happened this session (Jev prompting)

Daniel heard in a talk that Jev is not a thinker: the wording, the options and how many questions are asked decide
the results.

1. **The research report:** `research/jev-prompting:docs/research/jev-prompting.md` (`a311fed`; brief
   `docs/briefs/jev-prompting-research-brief.md`).
   - A deviation register of 33 rows: what Narrowing does, what Typesafe says (quoted), our recorded reason, our
     measurements, the likely cost, and a candidate lever.
   - I verified the key doc quotes live and recomputed the new numbers independently.
   - New findings:
     - The Gateway serves `typesafe-ai/jev` from **TypeSafe or DigitalOcean**. On identical requests DigitalOcean's
       answers differ by a median of 0.16 and flip 24 of 146 choices. Between two TypeSafe answers it is 0.02 and
       23 of 705.
     - The order of the `probabilities` map is undefined: random on TypeSafe, alphabetical on DigitalOcean.
2. **Decisions** (Daniel's answers to the numbered questions; both recorded on #52):
   - **Q1: 1, the three groups** below, now a standing rule.
   - **Q3: 1, research and analysis first:** attach the research to #52, run the $0 offline analysis now, hold the
     live round.
   - [Decision and levers comment on #52](https://github.com/DanielMulec/jevpaste/issues/52#issuecomment-5961805076)
     and [offline results comment](https://github.com/DanielMulec/jevpaste/issues/52#issuecomment-5961893330).
3. **The offline analysis:** `spike/narrowing-offline:spikes/narrowing/offline/FINDINGS.md` (`9131ec7`; brief
   `docs/briefs/narrowing-offline-analysis-brief.md`). I re-ran every script; replaying the recorded answers
   reproduces all 164 pastes. Results:
   - **Containment mass: no.** Dropped.
   - **Top-two gap:** no gate. Logging the weakest step's p1 is a candidate, not decided.
   - **Carry 0.05 and width 2:** each loses nothing on the recorded data. Worth a cheap live test in #52's round.
   - **Tie order:** no outcome changes. → #61.
   - **Upstream:** a control, not a fix. → #60.
4. **Daniel's later answers:** **Q2: 1, keep #60** (after the clarification), and **Q4:** build #60 and #61 in the
   next session.

## Open issues

- **To build next:** #61, then #60.
- **`triage`:**
  - #52, on hold, with the levers listed in its comments;
  - #55, onboarding, which belongs to the future map;
  - #59, which secret rule refused.
- **`parked`:** #57 (copies too big for one Jev call), #58 (consider removing the secure-field pre-check).

## Two tracks (unchanged)

1. **Daily-use refinements are plain issues:** `triage` → `/grill-with-docs` → `/implement` (worker slice, below).
   - `parked` means a deliberate gap.
   - Bugs go to `/diagnosing-bugs`.
   - Rule of thumb: a sharp question → a plain issue; a foggy cluster → a map.
2. **"Other users from the public repo" is a new wayfinder map, not yet charted.** The cluster:
   - the product name: keep the Jev/Jevons shoutout. Whether "Jev" may appear at all is a Typesafe brand-terms
     question; research it first;
   - Typesafe keys have **no documented format**, which matters for onboarding;
   - a public website;
   - the **licence**: the repo is public but unlicensed, so it is not open source;
   - onboarding (#55);
   - publication hygiene.

   Chart it only when Daniel is up for a HITL grilling session: destination first, then breadth-first.

## Installed app

- `~/Applications/JevPaste.app` is the code of `4b6bc33`. Everything since is docs only.
- Both key files are present (`~/.config/jevpaste/keys/<provider>`), and the Accessibility grant is trusted.
- Provider: Vercel AI Gateway.
- Live suites: `JEVPASTE_LIVE_JEV=1 make test`. It never prints keys.
- Find the running pid with `pgrep -x JevPaste` before quitting it.

## Build protocol

- **Worker:** a fresh Opus 5.5 **medium** in a Herdr tab per slice.
  - Commands: `herdr tab create --cwd <worktree> --label <name> --no-focus`, then
    `herdr agent start <name> --kind pi --pane <id> --timeout 60000 -- --model anthropic/claude-opus-5-5:medium`,
    then `herdr agent prompt`.
  - Worktrees live under `~/.pi/worktrees/jevpaste/<name>`.
  - The brief goes in `docs/briefs/<slice>-brief.md` on `main`. Latest implementation pattern: `opaque-token-brief.md`.
  - Gates: Gate A (design) → Gate B (diff read by you) → install, plus Daniel's live block relayed by you → Gate C
    (run log and report comment).
- **Review:** a fresh **`openai-codex/gpt-5.6-sol:medium`** in a detached worktree at the branch head.
  - Put an untracked `REVIEW-BRIEF.md` there with five specific questions and the sections
    VERDICT / BLOCKING / NON-BLOCKING / DUPLICATION / GAPS / METHOD.
  - The reviewer must `intercom send <your-id>` last.
  - A delta review is a **fresh** reviewer with the prior verdict quoted in its brief.
- **Merge and install:**
  1. `git merge --no-ff origin/<branch>` on `main`, `make check`, push.
  2. `make install`, quit the old app by pid, `open ~/Applications/JevPaste.app --args --accept-signal-trigger`.
  3. Post the resolution comment and close the issue.
  4. Clean up the tab and worktree: `git worktree remove` **before** `git branch -d`. Delete the branch locally and on
     origin.
- **Research or analysis workers:** same launch commands.
  - They write without committing; you verify the claims (re-run the scripts, recompute the key numbers, fetch the
    key quotes) and commit on the research or spike branch, which is never merged.
  - Reusing the same worker session for a direct sequel worked well: it already knew the data.
  - A Herdr **pane** split (`herdr pane split <pane> --direction right --no-focus`) also works when Daniel wants to
    watch.
- **Daniel's live steps:** write them as a numbered block in plain words. Relay his results verbatim to the worker.
  The worker reconciles every step from the log and DB (`JEVPASTE-…` rows only); never trust words alone.
- **Check the tab id before `herdr tab close`.** Herdr may create tabs in another workspace (`wB` vs `wC`); that is
  harmless.
- **Other lessons:**
  - The app log does not name the matching secret rule (#59).
  - Worker Pi sessions have 0 MCP servers; open Chrome pages with AppleScript (`open location "data:…"`).
  - `yt-dlp` captions can hit HTTP 429 from this Mac.

## Lessons from this session

- **"Jev Provider" is not "upstream".** Daniel read "restrict the Gateway to Typesafe's upstream" as "drop Vercel".
  - He wants **both Jev Providers**: the Vercel AI Gateway and Typesafe direct.
  - Say "the servers behind the Gateway" and write "both Jev Providers stay" explicitly. `CONTEXT.md` already lists
    "provider" for upstreams under _Avoid_.
- **`../jevsearch` is an independent sister project** (a Chrome extension that also uses Jev, with Nouls).
  - Use its concepts only where they help jevpaste; otherwise ignore it entirely.
  - Its Typesafe source list was a useful map. Its audit of jevpaste found what became #60 and #61.
- **When Daniel asks "everywhere we use X", scope it.** My first answer missed that jevsearch also uses Jev, and
  Daniel then excluded it anyway. Name the scope you searched.

## Standing rules (still binding)

- **Jev-first:** everything that can be a Jev choice is a Jev choice. Local rules only where *sending* is the harm
  (secrets).
- **Paste Result:** one exact, contiguous, verbatim excerpt of the Active Item, never authored text.
- **Deviations from Typesafe's guidance** (Daniel, 2026-10-02, #52):
  1. Accidental (nobody decided it): fix it to match Typesafe.
  2. Deliberate and measured on held-out cells, with no documented Typesafe failure mode that matches one of our
     known misses: keep it.
  3. Deliberate but never measured against the guidance: Typesafe's guidance is the default, and #52 tests it.
- **`NarrowingPolicy` holds every wording and tunable.** A change there is a spike round's decision, measured on
  fresh held-out cells, never a quiet edit.
- **Code quality over speed.**
  - 400 lines per file, absolute.
  - `make check` is the gate.
  - A fresh-instance semantic-duplication review before every merge.
  - No hosted CI.
- **You orchestrate; workers build.**
  - Orchestrator latitude, without asking: read code, probe cheaply, merge and `make check`, install, keep the
    tracker up to date, kill runaways.
  - Product decisions go to Daniel as short numbered questions, each with a recommendation. He answers "Q1: 1" style;
    repeat the mapping in your reply.
  - When he says "I have to trust you", decide and say what you decided.
- **Secrets and committed text.**
  - Never print `~/.config/jevpaste/env`, `~/.config/jevpaste/keys/*`, a key's length or prefix, or any history row
    other than `JEVPASTE-…` rows.
  - Committed logs carry no literal text, no window titles and no `/Users/<name>` paths.
- **Relaunching the app:** restore the clipboard vault first (Launch Adoption). Send signals by pid only.
- **Chrome DevTools MCP** (orchestrator side): use your own tabs, and re-list before `close_page`. The "Allow remote
  debugging?" sheet is Daniel's.
- **Where Daniel writes from:** the laptop; screenshots land in `~/Desktop/Bildschirmfoto …png`. Give phone
  instructions only for Telegram-originated messages.
- **Any new text field:** `usesSingleLineMode`, `wraps = false`, `isScrollable`, and a red-first layout test.
- **This handoff** lives in `docs/HANDOFF.md` and is written before ~200k context.

## Suggested skills for the next session

- `ask-matt`: the router.
- `implement`, with `tdd` inside, for the #61 and #60 worker briefs. `code-review` is the in-repo GPT review above.
- `diagnosing-bugs` if a live proof misbehaves.
- `grill-with-docs` (with `grilling` and `domain-modeling`) for #52 once daily-use misses arrive, or for any `triage`
  issue.
- `wayfinder` only for the "other users" map.
- `research` first for the Typesafe brand-terms question.
