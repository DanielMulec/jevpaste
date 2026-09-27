# Brief — Add Typesafe direct as a Jev Provider (issue #54)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/typesafe-direct`, branch `typesafe-direct` (forked from `main` at or after `0dd7de3`).
This is a **production slice**: TDD, review chain, merged when done. Your supervisor is the Pi session with intercom
id **`01a0e1db-647e-77bc-8ce1-3ce753ac3478`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly
that id; ignore any other id you find in briefs or docs. Daniel (owner) speaks **only through the supervisor** —
every live step where Daniel acts is an `intercom ask`, and you wait. You are the only worker; the installed app is
Daniel's daily tool — `make install` only when a gate reply says go.

Communication protocol:
- `intercom send <supervisor>` one line after every numbered step: `[typesafe] step N done — <fact>`.
- `intercom ask <supervisor>` (blocking) at each **GATE** and for every live action; prefix with `[typesafe]`.
  An ask may time out on your side while Daniel is away — it stays valid; idle, do not re-ask, do not poll.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`; if that fails, `send`.
- Never block in a long sleep. **Never print the contents of `~/.config/jevpaste/env` or `~/.config/jevpaste/keys/*`,
  never a key, never a key's length or prefix.** Never log or print Clipboard Item text. Committed logs carry no
  literal text (no window titles, no `/Users/<name>` paths); Jev payloads appear only as the labelled-field form
  the existing acceptance logs use.

## Read first (in this order)
1. `gh issue view 54` — your ticket (assigned to Daniel = claimed; leave it). Its body is the scope.
2. Your contract, verbatim:
   - `gh api repos/DanielMulec/jevpaste/issues/comments/5849649811 -q .body` — resolution of
     [Decide how JevPaste supports Typesafe direct alongside the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/45):
     **decisions 7 and 8** are yours; 1, 4, 9 constrain you.
   - `gh api repos/DanielMulec/jevpaste/issues/comments/5839522535 -q .body` — resolution of
     [Establish Typesafe's direct Jev API versus the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/44),
     and its findings file: `git fetch origin research/typesafe-direct` then
     `git show origin/research/typesafe-direct:docs/research/typesafe-direct.md` (§3 is the field-by-field table).
     Research is a snapshot from 2026-09-25 — verify the facts against the live API in step 3, do not trust them blindly.
   - `gh api repos/DanielMulec/jevpaste/issues/comments/5854285929 -q .body` — resolution of
     [Implement the status-item menu with History Search and the Settings window](https://github.com/DanielMulec/jevpaste/issues/53)
     (what you inherit: file key store, `JevGatewayAccess.builtProviders`, `JevConnectionTest`, the Settings rows).
3. `CONTEXT.md` (**Jev Provider**, **Paste Attempt**, **Narrowing**, **Active Item**), `gh issue view 1` **Notes**
   (400 lines/file incl. tests; no payloads in logs; no credentials in source; refer to issues by title),
   `docs/quality-gate.md`, `docs/design/jev-gateway.md`, `docs/design/narrowing.md`,
   `docs/design/menu-and-settings.md` (Keys, Settings, Test), `Makefile`.
4. Code you will touch:
   - `Sources/JevGateway/*` — today one request path for the Vercel AI Gateway: `EvaluateRequestBody` (model
     `typesafe-ai/jev`), `EvaluateResponse`, `JevRefusal` (400 + `max_tokens_exceeded` → `.tooLarge`),
     `RateLimit`, `JevGatewayFailure`, `JevGatewayAccess` (`builtProviders = [.vercelAIGateway]`),
     `JevConnectionTest`, `HTTPTransport`. Becomes: **one module, a per-provider table** (decision 7): URL, auth
     header, model id (`typesafe-ai/jev` via the Gateway, `jev-1.13.0` direct — pinned), error mapping (Gateway 400
     wrapping vs direct 422 validation / 429 with optional `retry-after` or `retry-after-ms` / 529 overloaded),
     response differences (`usage` snake_case, no `providerMetadata`). Shared encoding and parsing; no second
     request path, no second decision service. A missing key is `403` in practice direct (docs say 401) — both map
     to the same failure.
   - `Sources/JevPasteApp/Settings/*`, `Sources/JevPasteApp/Keys/*` — enable the Typesafe radio and its key row
     (they exist, gated by `builtProviders`); the key file `~/.config/jevpaste/keys/typesafeDirect` follows from
     the store (keyed by raw value). No import for Typesafe (there is no env key). Test button wording per provider.
     The capture exclusion (`StoredKeyCaptureExclusion`) already covers every stored key — verify with a test that
     a Typesafe key is excluded too.
   - `README.md` — both providers, where keys live, the DigitalOcean/ZDR note for the Gateway (research finding 5),
     Typesafe's prepaid-credit note. Short.
   - Tests in `Tests/JevGatewayTests/` (fixtures per provider; `JevGatewayLiveTests` reads the env file today —
     extend to read the **file key store** per provider, still gated by `JEVPASTE_LIVE_JEV=1`, never printing
     keys) and `Tests/JevPasteAppTests/`.
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).
   If a link fails with an undefined-symbol mangling mismatch after adding files, `swift package clean` first.

## Scope
1. **Provider table** in `JevGateway`: Typesafe direct built and selectable; every request of a Paste Attempt
   goes through the provider chosen when it started (already true via `JevProviderAccess`; don't touch Core
   unless a seam genuinely needs a new value — say so at Gate A).
2. **Error mapping** per provider, by fixture: direct 422, 429 (+`retry-after`, +`retry-after-ms`, neither),
   529, 403/401 missing key, `max_tokens_exceeded` in its direct form; Gateway fixtures stay green untouched.
3. **Settings**: Typesafe radio + key row enabled, Test works through the same `JevConnectionTest`, result
   wording names the provider.
4. **Live proof** (decision 8), recorded in `docs/acceptance/run-<date>-typesafe-direct.log`:
   (i) the 14 recorded Narrowing cells (`Tests/JevGatewayTests/Fixtures/narrowing-replay.jsonl`) replayed **live**
   through **both** providers → same outcomes (probabilities may differ; record per cell: outcome, p, latency);
   (ii) 429/529 by fixture (offline, cite the tests); (iii) cold and warm latency per provider (≥ 3 warm calls,
   medians); (iv) Daniel's block in the installed app (below).
5. **Docs**: `docs/design/jev-gateway.md` updated for the table (≤ 90 lines total), README as above.

Out of scope: onboarding on first launch, secret screening beyond stored keys, any change to Narrowing, Pre-check
rules or the chooser, notarization, a licence, a Typesafe key in any file of the repo or any log.

## Steps
1. Read, then write the design delta into `docs/design/jev-gateway.md`. **GATE A**: ask with the doc path and
   your proposals: the table's shape (a value per provider vs. protocol), where model ids and endpoints live,
   the error-mapping table (provider × status → failure), how the live replay harness runs (a test gated by env
   var per provider, or a script — say which and why; it must never print a key or payload text), the file plan
   (every new/changed file with an expected line count). Wait for the reply.
2. Implement TDD, small commits (`make check` green before each). Push after each gate.
3. **GATE B**: ask with the `make test` summary line, `wc -l` of every file you touched, one-line proof per
   scope item (test names). The supervisor reads the JevGateway and Settings diff before approving.
4. Live proof. First `ask` for `make install` (go = install, quit Daniel's app by pid, `open
   ~/Applications/JevPaste.app --args --accept-signal-trigger`, confirm `launch provider=… apiKeyPresent=true` in
   the log). Then one `ask` with Daniel's block, plain words, say why each step exists:
   (a) Settings → Jev Provider: the Typesafe radio is enabled; paste his Typesafe key into its field (he has it
   ready; you never see it) → Test → "✓ Works — Jev answered through Typesafe direct" (exact wording as built);
   (b) select Typesafe direct as the provider, ⌘W; in a Chrome field you opened for him (`data:` page, own tab)
   ⌘⇧V with a synthetic Active Item you staged via `pbcopy` (`JEVPASTE-TS-54` + a synthetic email, pure values
   per line) → the value lands; log shows `provider=typesafeDirect` on that attempt;
   (c) switch back to Vercel AI Gateway, ⌘⇧V again → lands, log `provider=vercelAIGateway`; (d) Settings → Jev
   Provider: clear the Typesafe key, Test → the visible error names the provider; paste it back (he pastes; you
   verify from the log only: `key for typesafeDirect stored`). Reconcile every step from the log, not his words.
   Only after Daniel's key is stored: run the live replay (i) and latency (iii) from your shell with
   `JEVPASTE_LIVE_JEV=1`, reading both keys from the file store. Restore the clipboard vault before relaunching.
5. Push. Post a report comment on issue #54: what was built, the table, test count, live evidence per step
   (replay table of 14 × 2), commits, open questions. **GATE C**: ask with the comment URL, then end your turn.
   Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Glossary names. No new dependencies without `ask`. Commit small on `typesafe-direct`. Bare `swift test` does not
  link — use `make test`. Do not merge.
- Fakes model visible state. Fixtures use obviously fake keys (`fake-key-…`).
- Reviewers read the committed log, not your session: every count/digest/latency backing a claim goes into the log.
- If your context grows past ~300k, write `docs/briefs/typesafe-direct-worker-handoff.md` on the branch and tell
  the supervisor; a fresh worker continues.

## Report format
`[typesafe] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
