# Brief — Port the MacInterop adapters from the probe (issue #22)

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/mac-interop`, branch `mac-interop` (forked from `main` at bef15f9). Your supervisor is the
Pi session with intercom id **`01a0ca65`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`). Use exactly
that id. Daniel (owner) speaks through the supervisor. Two other workers run in parallel on sibling
slices — do not touch their modules.

Communication protocol:
- `intercom send 01a0ca65` one line after every numbered step: `[mac-interop] step N done — <fact>`.
- `intercom ask 01a0ca65` (blocking) at each **GATE**; prefix the message with `[mac-interop]`. Do not continue until answered.
- Anything unexpected → `ask` first. Answer asks you receive with `intercom reply`, never `send`.
- Never block in a long sleep. Never print the contents of `~/.config/jevpaste/env`.

## Read first (in this order)
1. `gh issue view 22` — your ticket. Claim it: `gh issue edit 22 --add-assignee @me`.
2. `gh api repos/DanielMulec/jevpaste/issues/comments/5782480932 --jq .body` — the **state-machine report**:
   the port shapes you implement against and the obligations for your slice. Do not change Core ports;
   if a port shape truly cannot work, `ask` before touching Core.
3. The Core sources: `Sources/SmartPasteCore/Seams/*.swift`, `Sources/SmartPasteCore/Values/*.swift`,
   `docs/design/paste-attempt-state-machine.md`.
4. `gh issue view 16 --comments` (slice plan + acceptance), `gh issue view 1` **Notes** (hard rules:
   400 lines/file incl. tests; no secrets in source; no payloads in diagnostic logs; verbatim excerpt only;
   refer to issues by title), `CONTEXT.md` (vocabulary), `docs/quality-gate.md`, `Makefile`.
5. Skills: `~/.agents/skills/tdd/SKILL.md`, `~/.agents/skills/codebase-design/SKILL.md`.
6. Run `npm ci` and one plain `swift build` before the first commit (the pre-commit hook cannot fetch deps).

## Rules
- TDD (red-green-refactor), Swift Testing, Swift 6 strict concurrency. `make check` green before every commit.
- ≤ 400 lines per file, split by concern. Descriptive names from the glossary. No new dependencies without `ask`.
- Remove the `// periphery:ignore` comments in Core **only** on the properties your adapter now reads (listed in the report).
- Commit small on `mac-interop`; push after each gate. Do not merge.

## Scope
`Sources/MacInterop/` + `Tests/MacInteropTests/` + a small `scripts/` probe runner if needed. Implement
`Clipboard`, `Hotkey`, `TargetResolver`, `Inserter` from the probe on `spike/macos-probe`
(`~/.pi/worktrees/jevpaste/macos-probe/spikes/macos-probe/` — read `RESULTS.md`, `HANDOFF.md`, `Sources/`)
and the findings in `gh issue view 11 --comments` and `gh issue view 3 --comments`.

## Rules specific to this slice
- Obligations from the state-machine report are binding: `Inserter` posts ⌘V only (never Return, never a
  key-sequence path); `Clipboard.write/restore` return the new changeCount; change notifications arrive by
  polling on a later run-loop turn, never synchronously inside write/restore; `ClipboardChange.item` carries
  restored text too and the concealed/transient marker (`org.nspasteboard.ConcealedType`,
  `org.nspasteboard.TransientType`) → `isConcealed`; the resolver mints `elementToken`, sets `isSecureField`
  (`AXSecureTextField` **or** `IsSecureEventInputEnabled()`), and `isStillFocused` compares pid + element.
- Target Context per the Jev contract: field label, placeholder, section heading, sibling labels when AX offers
  them; bounded (~2 000 chars) visible surrounding text otherwise; terminals get the window scrape.
- Hotkey: Carbon `RegisterEventHotKey` or `NSEvent` global monitor, whichever the probe proved; ⌘⇧V.
- Unit tests: what is testable without AX (pasteboard round-trip on a private `NSPasteboard(name:)`, marker
  detection, change-count bookkeeping, context truncation). AX and keystroke paths are proven by a **signed
  probe run**: build a tiny throwaway executable target or reuse `JevPasteApp` behind a `--probe` flag, sign
  with `jevpaste-dev` via `make app` machinery (never ad-hoc, never install over `~/Applications/JevPaste.app`
  without asking), and paste **synthetic** text into Chrome (a `data:` URL textarea) and Ghostty. Ask the
  supervisor before any step that pastes into a real app; Daniel answers `done`/`nothing`/`failed`.
- The Accessibility grant exists for `~/Applications/JevPaste.app` (identity `jevpaste-dev`). A separate
  probe binary signed with the same identity but a different bundle id will need its own grant — prefer the
  `--probe` flag approach on the real bundle so the existing grant applies. Ask before choosing.

## Steps
1. `docs/design/mac-interop.md` (≤ 100 lines): per adapter — mechanism, threading, what is unit-tested vs
   probe-proven, and the probe plan. **GATE A**: ask with the path.
2. Implement TDD for the testable parts; implement the AX/keystroke parts from the probe code.
3. Probe run (ask first). Proof = for Chrome and Ghostty: inserted text matched, original clipboard restored
   byte-for-byte after 120 ms, nothing sent.

## Final steps (after the slice steps above)
- `make check` green from a clean tree. **GATE B**: ask with the `swift test` summary line, `wc -l` of your files, and the proof evidence named above.
- Post a report comment on issue #22: what was built, test count, proof evidence, deviations, open questions. **GATE C**: ask with the comment URL, then end your turn. Do not merge.

## Report format
`[mac-interop] step N done — <one line of fact>` (no adjectives). Gates: the evidence asked for, nothing else.
