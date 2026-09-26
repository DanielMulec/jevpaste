# Brief — Implement the status-item menu with History Search and the Settings window (issue #53)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium` — Daniel's choice for this slice, 2026-09-26) in
worktree `~/.pi/worktrees/jevpaste/menu-settings`, branch `menu-settings` (forked from `main`). This is a
**production slice**: TDD, review chain, merged when done. Your supervisor is the Pi session with intercom id
**`01a0df77-ec24-77bc-8ce1-3ce59910d298`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly
that id; ignore any other id you find in briefs or docs. Daniel (owner) speaks **only through the supervisor** —
every live step where Daniel acts is an `intercom ask`, and you wait. You are the only worker; the installed app
is Daniel's daily tool — `make install` only when a gate reply says go.

Communication protocol:
- `intercom send <supervisor>` one line after every numbered step: `[menu] step N done — <fact>`.
- `intercom ask <supervisor>` (blocking) at each **GATE** and for every live action; prefix with `[menu]`.
  An ask may time out on your side while Daniel is away — it stays valid; idle, do not re-ask, do not poll.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`; if that fails, `send`.
- Never block in a long sleep. **Never print the contents of `~/.config/jevpaste/env`, any key, or any Keychain
  item.** Never log or print Clipboard Item text; refer only to `JEVPASTE-…` synthetic rows. Committed logs carry
  no literal text (no window titles, no `/Users/<name>` paths).

## Read first (in this order)
1. `gh issue view 53` — your ticket (assigned to Daniel = claimed; leave it). Its body is the scope.
2. The two decisions that are your contract, verbatim:
   - `gh api repos/DanielMulec/jevpaste/issues/comments/5849649811 -q .body` — resolution of
     [Decide how JevPaste supports Typesafe direct alongside the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/45):
     decisions 2–6 and 9 are yours (7–8 belong to the next ticket).
   - `gh api repos/DanielMulec/jevpaste/issues/comments/5850253565 -q .body` — resolution of
     [Prototype the status-item menu with History Search and the Settings window](https://github.com/DanielMulec/jevpaste/issues/37):
     the settled look and behaviour, and "For the build".
3. The prototype (throwaway, never merged; **the look is the spec, the code is not**): the worker report
   `gh api repos/DanielMulec/jevpaste/issues/comments/5850238509 -q .body`, then on branch
   `prototype/menu-settings` (`git fetch origin prototype/menu-settings`): `git show origin/prototype/menu-settings:PROTOTYPE-PLAN.md`
   (the **Settled** section holds the AppKit facts — how the panel takes key focus without activating, event
   handling for ↑/↓/Enter/Esc, resize with a fixed top edge, insets) and
   `git show origin/prototype/menu-settings:Sources/MenuSettingsPrototype/<file>` for the panel, row and Settings
   code. Read it to learn; **rewrite** it properly under `make check` (prototype rules: no tests, no error
   handling — none of that ships as is). The chosen screenshots are linked from the #37 resolution.
4. `CONTEXT.md` (**History Search**, **Full History**, **Jev Provider**, **Active Item**, **Clipboard Item**,
   **Clipboard History**, **Launch Adoption**), `gh issue view 1` **Notes** (400 lines/file incl. tests; no
   payloads in logs; no credentials in source; refer to issues by title), `docs/quality-gate.md`,
   `docs/design/app-shell.md`, `docs/design/history-ui.md` (the panel you remove — its Core seam `ActiveItemChange`
   stays), `docs/design/capture-and-history.md`, `docs/design/history-store.md`, `docs/design/jev-gateway.md`,
   `docs/design/candidate-chooser.md` + `docs/design/no-suitable-match-offer.md` (`KeyPanelSession`, the
   non-activating key-capable panel pattern you reuse), `docs/design/hardening.md` (Open at Login), `Makefile`.
5. Code you will touch:
   - `Sources/JevPasteApp/MenuBarDelegate.swift` — today builds an `NSMenu` (Clipboard History…, Open at Login,
     Quit). Becomes: status-item click opens the **History Search panel**; no `NSMenu` (the prototype proved a
     field inside a real menu is dead after one arrow press).
   - `Sources/JevPasteApp/HistoryPanel/*`, `Sources/JevPasteApp/History/ClipboardHistoryOpening.swift`,
     `Sources/JevPasteApp/Launch/LoginItemMenu.swift` — **removed** (periphery will insist). Keep
     `LoginItemToggle` (it moves to Settings → General) and `IndicatorNotice+History/+Selection` if still used.
   - `Sources/JevPasteApp/Chooser/*`, `StatusItemPanelParts.swift` (keep the explicit `@MainActor` on
     `FirstClickView`), `Sources/JevPasteApp/KeyPanel/*` — the panel, placement and key-session parts to reuse or
     generalise (one shared panel base, not a copy — the reviewer checks duplication with jscpd and by reading).
   - `Sources/SmartPasteCore/Seams/HistoryRepository.swift` + `Sources/HistoryStore/SQLiteHistoryRepository.swift`
     — **History Search**: query → newest ≤ 5 matching Clipboard Items + total match count. Propose at Gate A
     whether it is a new seam method with SQL `LIKE`/`instr` (case-insensitive substring over the whole text;
     note `trim()` strips spaces only — compare with `LIKE`) or app-side filtering over `items()`; say why.
   - `Sources/SmartPasteCore/Capture/CopyCapture.swift` — `select(_:)` and `observeActiveItemChanges` exist
     (one observer, the shell). The placeholder and an open panel/Settings need the current Active Item's first
     line and change notifications — extend without a second observer slot if the shell can fan out.
   - `Sources/JevGateway/GatewayCredentials.swift` + `JevGatewayDecisionService.swift` — the key comes from a
     **credentials seam** (protocol in `JevGateway` or Core: `apiKey(for: JevProvider) -> String?`), implemented by
     a **Keychain store** in the app layer (Security framework generic password, one item per provider,
     service name for JevPaste, never logged) and by an in-memory fake in tests. `GatewayCredentials` (env file)
     survives only as the **one-time import** source: on launch, if the Keychain holds no Vercel key and the env
     file has one, store it in the Keychain and remember the import (UserDefaults flag); the env file is not
     deleted and never read again. Tests keep a temp-file seam for the import.
   - New `JevProvider` value (Core or JevGateway; `vercelAIGateway`, `typesafeDirect`; display names from the
     glossary; default `vercelAIGateway`), persisted choice (UserDefaults), read **once per Paste Attempt** at
     ⌘⇧V (decision 9: no switch mid-flight).
   - **Refusal**: no key for the chosen provider → visible refusal `No key for <provider> — open Settings`, and
     a click on it opens Settings on Jev Provider with that provider's key field focused (see the prototype's
     "open to key" entry). Pre-check or Core outcome? Propose at Gate A (it is a local refusal before any Jev
     call, like `LocalPreChecks`; the indicator already handles click via `KeyPanelSession`/click-to-cancel).
     Today's "Jev unavailable" path for a missing key goes away.
   - **Settings window** (`Sources/JevPasteApp/Settings/*`): standard toolbar-tab window — General (Open at
     Login switch, reusing `LoginItemToggle`), Jev Provider (radio picker; per provider a secure key field, eye
     Show toggle, Test button with the inline result exactly as settled; editing clears the result), Full History
     (two-line rows, "Active" tag, per-item ✕, guarded Clear History… — the operations the old panel had).
     **Typesafe direct in this slice:** listed as the second radio but **disabled** (its key row too) until
     [Add Typesafe direct as a Jev Provider](https://github.com/DanielMulec/jevpaste/issues/54) enables it —
     unless you argue otherwise at Gate A. Test = one cheap Jev call through the chosen provider (a one-option
     choice question is enough; reuse the adapter, no second request path).
   - `Sources/JevPasteApp/Indicator/OutcomeMessage.swift`, `IndicatorPresenter.swift` — the new refusal text and
     log key (`reason=noProviderKey` or similar; enums only).
   - Tests in `Tests/SmartPasteCoreTests/`, `Tests/HistoryStoreTests/`, `Tests/JevGatewayTests/`,
     `Tests/JevPasteAppTests/` as they exist.
6. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
7. Tools for the live proof: Chrome DevTools MCP `chrome-devtools` (lazy: `mcp({connect:"chrome-devtools"})`
   first; drives Daniel's real Chrome — own tabs only, re-list and verify the title before `close_page`; a new
   connection may raise Chrome's "Allow remote debugging?" sheet — `screencapture`, ask, touch nothing). Herdr
   CLI for terminal steps. The installed app started with `open ~/Applications/JevPaste.app --args
   --accept-signal-trigger` accepts `kill -USR1 <pid>` (pid only, never `pkill`) as ⌘⇧V. Launch via `open …`,
   never from your shell. Logs: `log show --predicate 'subsystem == "jevpaste" AND process == "JevPaste"' --info --last 2m`.
8. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps;
   first commit ≈ 1 min). If a link fails with an undefined-symbol mangling mismatch after adding files,
   `swift package clean` first.

## Scope
1. **History Search panel** replaces the menu: status-item click opens a non-activating key-capable panel under
   the item — search field (placeholder = Active Item's first line; ✕ clears), while typing: dim "N of M
   matches", up to five two-line rows (first line; dim "N lines · age"; accent dot on the Active Item), then the
   item block **Full history… (M)** · **Settings…** · **Quit** in menu-item style (count in parentheses,
   right inset = titles' left inset); empty field → field · Settings… · Quit. ↑/↓ move, Enter chooses the
   highlighted row (else the first), a row click or Enter makes that item the **Active Item** and closes; **one
   Esc closes**; click-away closes; the panel re-lays out with a fixed top edge. Focus returns to the previous
   app as the chooser does. Nothing is pasted from the panel.
2. **Settings window** as above, opened by Settings… (and by the refusal, to the key). Standard window: closes
   with ⌘W, one instance, remembers nothing but what it edits. Provider choice and keys persist; the Active Item
   tag in Full History follows `ActiveItemChange`.
3. **Keys in the Keychain** with the one-time env-file import; `JevGateway` reads through the credentials seam;
   no key ever in logs, source or tests' fixtures (fakes use obviously fake strings).
4. **Refusal without a key**, clickable, opening Settings to the key; log line.
5. **Removal** of the Clipboard History panel and the old menu items; `docs/design/history-ui.md` marked
   superseded by a new `docs/design/menu-and-settings.md` (≤ 90 lines: panel mechanism and the AppKit facts,
   search seam, credentials seam + Keychain item layout + import rule, provider persistence and the per-attempt
   read, refusal path, Settings structure, test list, live-run plan in plain words).
6. **Live proof** (below) recorded in `docs/acceptance/run-<date>-menu-settings.log` (no literal text).

Out of scope: the Typesafe adapter (next ticket), onboarding on first launch, any change to Narrowing, Pre-check
rules or the chooser, notarization, a licence.

## Steps
1. `docs/design/menu-and-settings.md`. **GATE A**: ask with the doc path and your proposals: search seam
   (SQL vs app-side), credentials seam shape and where `JevProvider` lives, Keychain item layout and the import
   rule, the refusal's place (pre-check vs Core outcome) and click path, Typesafe disabled-or-selectable, which
   chooser/key-panel parts you generalise (names), and the file plan (every new/removed file with an expected
   line count). Wait for the reply.
2. Implement TDD, small commits (`make check` green before each). Push after each gate.
3. **GATE B**: ask with the `make test` summary line, `wc -l` of every file you touched, and a one-line proof
   per scope item (test names). The supervisor reads the Core, JevGateway and Settings/Keychain diff before
   approving.
4. Live proof — ask once for `make install` (the Keychain import runs on that first launch: report
   `apiKeyPresent`/imported facts from the log, never the key). **Keychain risk to verify first:** the item is
   created by the `jevpaste-dev`-signed app; after a **second** `make install` (rebuild, same identity) the app
   must read it back without a Keychain prompt — prove it with two installs before Daniel's block. Then one `ask`
   with Daniel's block, plain words, say why each step exists:
   (a) click the JevPaste status item → the panel with his Active Item's first line as placeholder; type a few
   letters of a **synthetic** row you staged beforehand via `pbcopy` (e.g. `JEVPASTE-MENU-53 menu53@example.org`
   on two lines — pure values per line) → rows appear; press ↓ once and type another letter (the field must keep
   editing — the prototype's finding); click the row → panel closes; reopen → placeholder shows that row;
   (b) focus a labelled Chrome field you opened for him (`data:` page, own tab), ⌘⇧V → the staged value lands
   (Rejev-paste of a selected history item); (c) Settings… → Jev Provider: the Vercel key is present (masked),
   Test → ✓; (d) clear the Vercel key field, ⌘⇧V in the Chrome field → refusal "No key for Vercel AI Gateway —
   open Settings", click it → Settings opens on the key; paste the key back (you restore it from the Keychain
   backup you took, or he pastes — say which; never show it), Test ✓; (e) General: toggle Open at Login off and
   on (log/`SMAppService` status); (f) Full History: delete the `JEVPASTE-MENU-53` row with ✕; open Clear
   History… and **Cancel** (his real history must survive — never confirm it); (g) auto-hiding menu bar: open
   the panel, move the mouse down over the rows and type — does the bar hide, does the panel stay usable? Record
   his answer verbatim. Reconcile every step from the log/DB (`JEVPASTE-…` rows only), not from his words.
   Restore the clipboard vault before relaunching the app if you staged anything (Launch Adoption).
5. Push. Post a report comment on issue #53: what was built, seams added/removed, Keychain facts, test count,
   live evidence per step, commits, merge touchpoints, open questions, what the Typesafe ticket needs.
   **GATE C**: ask with the comment URL, then end your turn. Do not merge, do not close the issue.

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. ≤ 400 lines per file, split by concern.
  Glossary names. No new dependencies without `ask` (Security.framework is a system framework, fine). Commit
  small on `menu-settings`. Bare `swift test` does not link — use `make test`. Do not merge.
- Fakes model visible state (a fake that fires callbacks unconditionally is a review finding).
- Reviewers read the committed log, not your session: every count/digest backing a claim goes into the log.
- If your context grows past ~300k, write `docs/briefs/menu-settings-worker-handoff.md` on the branch
  (per-scope status, uncommitted files, traps) and tell the supervisor; a fresh worker continues.

## Report format
`[menu] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
