# Brief — Refuse any copied API key at ⌘⇧V, whatever its vendor (issue #56)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/opaque-token`, branch `opaque-token` (forked from `main` at or after the commit that adds
this brief). This is a **production slice**: TDD, review chain, merged when done. Your supervisor is the Pi session
with intercom id **`01a0e3db-bcc8-77bc-8ce1-3cea75651388`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id; ignore any other id you find in briefs or docs. Daniel (owner) speaks **only through the
supervisor** — every live step where Daniel acts is an `intercom ask`, and you wait. You are the only worker; the
installed app is Daniel's daily tool — `make install` only when a gate reply says go.

Communication protocol:
- `intercom send <supervisor>` one line after every numbered step: `[opaque] step N done — <fact>`.
- `intercom ask <supervisor>` (blocking) at each **GATE** and for every live action; prefix with `[opaque]`.
  An ask may time out on your side while Daniel is away — it stays valid; idle, do not re-ask, do not poll.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`; if that fails, `send`.
- Never block in a long sleep. **Never print the contents of `~/.config/jevpaste/env` or `~/.config/jevpaste/keys/*`,
  never a key, never a key's length or prefix.** Never log or print Clipboard Item text. Committed logs carry no
  literal text (no window titles, no `/Users/<name>` paths). Test fixtures use obviously fake tokens.

## Read first (in this order)
1. `gh issue view 56` — your ticket and your contract: the decision, the mechanism, the test corpus. Assigned to
   Daniel = claimed; leave it.
2. `CONTEXT.md` — **Suspected Secret**, **Opaque Token** (new), **Pre-check**, **Active Item**, **Direct Paste**,
   **Narrowing**, **Candidate**. Use these names in code, tests and docs.
3. `docs/design/pre-checks.md` — the existing rule table, the linear-time proof and the file layout. You extend
   this file; keep it ≤ 120 lines.
4. Code you will touch: `Sources/SmartPasteCore/PreChecks/{SuspectedSecretRule,SuspectedSecretRules,ScannedText,
   StructuredSecretShapes}.swift` (79 / 17 / 97 / 62 lines) and their tests in `Tests/SmartPasteCoreTests/`.
   `LocalPreChecks.swift` applies `SuspectedSecretRules.standard.firstMatch(in:)` to the Active Item's text, the
   surrounding text and the window title — your rule runs in all three places; that is intended and harmless.
5. `gh issue view 1` **Notes** (400 lines/file incl. tests; refer to issues by title), `docs/quality-gate.md`,
   `Makefile`. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).
   If a link fails with an undefined-symbol mangling mismatch after adding files, `swift package clean` first.

## Scope
1. **`opaqueToken` rule** — one `SuspectedSecretRule`, one new entry appended to `SuspectedSecretRules.standard`
   (last, so named-prefix rules still win the `name` in logs). Definition, exactly as decided: the *whole* text,
   trimmed of leading/trailing whitespace, is ≥ 16 bytes, contains **no** whitespace and none of `.` `/` `@` `:`,
   consists only of ASCII letters, digits, `-`, `_`, and contains at least one ASCII letter **and** at least one of
   digit / `-` / `_`. Linear, single pass, no regex. Unlike the other rules it is a whole-text shape, not
   "anywhere" — say so in its doc comment and in `pre-checks.md`.
2. **Prefix extension** — `vck_` (Vercel AI Gateway, documented; boundary + ≥ 20 `[A-Za-z0-9_-]`) and
   `sk_test_` (Stripe test; boundary + ≥ 16 `[A-Za-z0-9]`, mirror of `stripeLiveKey`). Add to `standard`.
   The existing `stripeLiveKey` negative test that uses `sk_test_` must be rewritten, not deleted: it now
   asserts the *other* rule matches.
3. **Tests, red first, from the corpus in the ticket** — a new `OpaqueTokenRuleTests.swift`: every must-refuse and
   must-not-refuse line as its own parameterised case; plus the adversarial-size case in the existing linear-time
   proof test (a 256 KB single token must finish well under the existing 5 s bound; a 256 KB token with one space
   in the middle must *not* match). Prefix additions go in `SuspectedSecretRuleTests`.
4. **Docs** — `docs/design/pre-checks.md`: two new rows in the rule table and one paragraph on the whole-text rule
   and why its false positives cost nothing (from the ticket). `README.md`: one sentence where suspected secrets
   are described, if they are; otherwise nothing.
5. **Live proof** in the installed app, recorded as `docs/acceptance/run-<date>-opaque-token.log` (labelled-field
   form as the existing logs; `JEVPASTE-…` synthetic values only): see step 4.

Out of scope: anything in Clipboard History (suspected secrets stay recorded, per the v1 decision), the
Candidate Chooser, Narrowing, the secure-field pre-check, an override or Direct Paste doorway for refusals, an
entropy measure, a gitleaks catalogue import, Settings, the key store. Do not touch `LocalPreChecks.swift` unless
a test forces you to — say so at Gate A if it does.

## Steps
1. Read, then write the design delta into `docs/design/pre-checks.md` (uncommitted is fine). **GATE A**: ask with
   your proposal: the exact byte-class check for the opaque token (how you do "at least one letter and one
   digit/-/_" in one pass), where it lives (own file or in `StructuredSecretShapes.swift` — mind 400 lines), the
   test file plan with expected line counts, and any corpus line you think is wrong. Wait for the reply.
2. Implement TDD, small commits (`make check` green before each). Push after each gate.
3. **GATE B**: ask with the `make test` summary line, `wc -l` of every file you touched, and one line per corpus
   entry: the test name that covers it. The supervisor reads the diff before approving.
4. Live proof. First `ask` for `make install` (go = install, quit Daniel's app by pid, `open
   ~/Applications/JevPaste.app --args --accept-signal-trigger`, confirm the launch line in the log). Then one `ask`
   with Daniel's block, plain words, say why each step exists. Stage every Active Item yourself via `pbcopy` — Daniel
   never types a real key. Chrome field: a `data:` page in a tab **you** open via Chrome DevTools MCP (own tab;
   re-list before `close_page`; the "Allow remote debugging?" sheet is Daniel's).
   (a) stage `JEVPASTE-OPQ-1-` + 32 fake base62 chars (one token) → Daniel ⌘⇧V in the field → indicator
   "Suspected secret — blocked", nothing inserted; log shows `refused reason=suspectedSecret rule=opaqueToken`.
   (b) stage `vck_JEVPASTEOPQ2` + 24 fake base62 chars inside a sentence ("the key is … for the demo") → ⌘⇧V →
   refused, `rule=vercelAIGatewayKey` (or whatever you named it).
   (c) stage a two-line address block with `JEVPASTE-OPQ-3` as the name and a synthetic email → ⌘⇧V in an email
   field → the email lands (the rule must not fire on structured text) — this is the regression cell.
   (d) stage a bare UUID → ⌘⇧V → refused; then Daniel presses plain ⌘V → the UUID lands (the accepted false
   positive costs one keystroke; prove it).
   Reconcile every step from the log, not his words. Restore the clipboard vault before relaunching the app.
5. Push. Post a report comment on issue #56: what was built, test count, the corpus → test mapping, live
   evidence per step, commits, open questions. **GATE C**: ask with the comment URL, then end your turn.
   Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Glossary names. No new dependencies. Commit small on `opaque-token`. Bare `swift test` does not link — use
  `make test`. Do not merge.
- Revert path is part of the design: the rule must be removable by deleting one entry from
  `SuspectedSecretRules.standard`; nothing else may depend on it.
- Reviewers read the committed log, not your session: every claim's evidence goes into the log.
- If your context grows past ~300k, write `docs/briefs/opaque-token-worker-handoff.md` on the branch and tell the
  supervisor; a fresh worker continues.

## Report format
`[opaque] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
