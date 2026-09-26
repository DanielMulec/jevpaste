# Brief — Research: official ChatGPT sign-in for a third-party macOS app (issue #48)

You are a fresh Pi session (`anthropic/claude-opus-5-5:high`) in worktree
`~/.pi/worktrees/jevpaste/chatgpt-signin`, branch `research/chatgpt-signin` (forked from `main`). This is a
**research** ticket: no production code, findings only. Your supervisor is the Pi session with intercom id
**`01a0dc7c`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`); use exactly that id.

Protocol: `intercom send 01a0dc7c "[chatgpt-signin] step N done — <fact>"` after each step; `intercom ask` for
anything unexpected. **Never sign up for anything, register an OAuth client, create accounts, or call any API with
a key or token.** Never print `~/.config/jevpaste/env` or any auth file under `~/.codex`, `~/.pi` or similar —
you may *describe* what pi/Codex CLI store, never their contents.

## Read first
1. `gh issue view 48` — the question, bullet by bullet.
2. `gh issue view 31 --comments` — the resolution that raised this (why a user's own ChatGPT account matters:
   GPT-6-Luna as a possible extractor for any-field Smart Paste).
3. `docs/research/jev-vercel.md` and `docs/research/typesafe-direct.md` — match their structure (summary,
   findings with citations, open questions, sources).
4. `~/.agents/skills/research/SKILL.md`.

## Method
Primary sources only: OpenAI's official developer documentation, platform/help pages, terms of use and usage
policies, the Codex CLI source (github.com/openai/codex) for how its ChatGPT login actually works today, and
OpenAI announcements. Follow every claim to the page that owns it; cite the URL per claim. Use `web_search`
(several angles: "Sign in with ChatGPT", "ChatGPT OAuth third-party apps", "Codex CLI ChatGPT login OAuth",
"OpenAI apps SDK", "ChatGPT subscription API access terms") and `fetch_content`. Distinguish clearly:
(a) what OpenAI officially offers third-party developers, (b) what Codex CLI does for itself, (c) what is
undocumented or unverifiable. No guessing.

## Deliverable
`docs/research/chatgpt-signin.md` answering every ticket bullet, ending with a **decision table**: ChatGPT
sign-in vs OpenAI API key vs Vercel AI Gateway — auth flow, models available (is GPT-6-Luna reachable?),
rate limits/cost to the user, terms (permitted for a personal-use native app? for other users?), what a user
sees, what would block JevPaste. Commit: "Research: official ChatGPT sign-in for a third-party macOS app (48)";
`git push -u origin research/chatgpt-signin`. Then comment on issue 48 (`gh issue comment 48 --body-file
<tmpfile>` — write the body to a file, no heredoc) with a link to the file on the branch and a five-line summary.
Do **not** close the issue. Finish with `intercom send 01a0dc7c "[chatgpt-signin] done — <comment URL>"`.
