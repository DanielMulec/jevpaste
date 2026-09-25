# Brief — Research: Typesafe's direct Jev API versus the Vercel AI Gateway (issue #44)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/typesafe-direct`, branch `research/typesafe-direct` (forked from `main`). This is a
**research** ticket: no production code, findings only. Your supervisor is the Pi session with intercom id
**`01a0da0a`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`); use exactly that id.

Protocol: `intercom send 01a0da0a "[typesafe] step N done — <fact>"` after each step; `intercom ask` for
anything unexpected. **Never sign up for anything, create accounts, or call any API with a key.** Never print
`~/.config/jevpaste/env`.

## Read first
1. `gh issue view 44` — the question, bullet by bullet.
2. `docs/research/jev-vercel.md` — the earlier gateway research; match its structure (summary, findings with
   citations, open questions, sources).
3. What the app sends today: `Sources/JevGateway/JevGatewayDecisionService.swift`, `EvaluateRequestBody.swift`,
   `EvaluateResponse.swift`, `RateLimit.swift`, `GatewayCredentials.swift`; `docs/design/jev-gateway.md`.
4. `~/.agents/skills/research/SKILL.md`.

## Method
Primary sources only: Typesafe's official site/docs/API reference/SDK source; Vercel AI Gateway docs for the
comparison side. Follow every claim to the page that owns it; cite the URL per claim. Use `web_search`
(multiple angles) and `fetch_content`. State plainly what is undocumented or unverifiable — no guessing.

## Deliverable
`docs/research/typesafe-direct.md` answering every ticket bullet, with a **field-by-field table** of our current
request/response shape vs Typesafe direct (each `EvaluateRequestBody`/`EvaluateResponse` field: same / renamed /
absent / new). Commit: "Research: Typesafe direct Jev API vs Vercel AI Gateway (44)";
`git push -u origin research/typesafe-direct`. Then comment on issue 44 (`gh issue comment 44 --body-file
<tmpfile>` — write the body to a file, no heredoc) with a link to the file on the branch and a five-line summary.
Do **not** close the issue. Finish with `intercom send 01a0da0a "[typesafe] done — <comment URL>"`.
