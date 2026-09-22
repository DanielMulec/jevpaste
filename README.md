# jevpaste

A personal macOS menu-bar app for smart paste. Copy a block of text — a résumé, an email signature, a
message — then press **⌘⇧V** in a text field: jevpaste asks Jev (through the Vercel AI Gateway) which exact
excerpt of the copied text belongs in that field, and pastes only that excerpt. The Paste Result is always one
exact, contiguous, verbatim excerpt of the Active Item; the app chooses *which* text and never authors any.
Ordinary ⌘V is unchanged, the original clipboard is preserved, and a local Clipboard History allows reusing
older items. Built for one person on one Mac; not a distributed product.

The idea comes from a 21.78 s screen recording
([tweet by Marcus Lowe](https://x.com/marcus_lowe/status/2101476399488160013)): one résumé copied in Preview,
then pasted field by field into a Chrome application form, each field receiving only its value. That recording
is behavioural evidence of the experience, not proof of how Jev works internally:
[`video.mp4`](video.mp4) and 22 extracted frames in [`frames/`](frames/), for example
[copy](frames/frame_005.png), [first paste](frames/frame_010.png) and [finished form](frames/frame_022.png).

Domain vocabulary (Active Item, Candidate, Paste Attempt, Bound Target, …): [`CONTEXT.md`](CONTEXT.md).
Status: scaffold only — the app shows a menu-bar icon with a Quit item and no behaviour yet.

## Prerequisites

- macOS 14 or later, Apple silicon.
- **Command Line Tools only** (`xcode-select --install`), Swift 6.3 or later. Xcode is not needed and nothing in
  the repository may require it ([ADR 0001](docs/adr/0001-clt-only-swiftpm-app-with-hand-assembled-signed-bundle.md)).
  Tests use Swift Testing through the `swiftlang/swift-testing` package plus two CLT linker flags kept in the
  `Makefile`.
- Homebrew: `brew install swiftlint periphery`.
- Node.js for jscpd: `npm ci` installs the version pinned in `package.json`.
- The `jevpaste-dev` Signing Identity in its dedicated keychain, for `make app` / `make install`
  (see [Signing](#signing)).

## Commands

| command | what it does |
|---|---|
| `make check` | the whole local quality gate, offline and fail-fast: strict build → swift-format → SwiftLint → jscpd → `swift test` → Periphery → line-count guard |
| `make format` | formats `Sources` and `Tests` in place with swift-format |
| `make app` | release build, assembles `build/JevPaste.app`, writes its `Info.plist` and icon, signs it with `jevpaste-dev` |
| `make install` | `make app`, then copies it to `~/Applications/JevPaste.app` (constant path; no sudo) |
| `make acceptance` | placeholder for the real-app acceptance suite; never part of `make check` |

Run it with `open ~/Applications/JevPaste.app`; quit from its menu-bar icon.

Every rule, threshold, tool version and exit code of `make check`, with proof that each rule fires:
[`docs/quality-gate.md`](docs/quality-gate.md). There is no hosted CI.

### Pre-commit hook

Run `scripts/install-hooks.sh` once per clone. It installs a git pre-commit hook that runs `make check` and
blocks the commit if any step fails. The hook checks the working tree, not only the staged changes.

## Signing

Installed builds are signed with the self-signed identity `jevpaste-dev`, never ad-hoc. macOS Accessibility
trust keys on the designated requirement, which is anchored to that certificate, so rebuilds keep the grant.
`security find-identity -v` shows 0 valid identities because the certificate is untrusted
(`CSSMERR_TP_NOT_TRUSTED`); that is expected and it signs fine. Decision and evidence:
[ADR 0001](docs/adr/0001-clt-only-swiftpm-app-with-hand-assembled-signed-bundle.md) and
[Establish a signing identity that keeps the Accessibility grant across rebuilds](https://github.com/DanielMulec/jevpaste/issues/13).
Keychain layout and recovery (`scripts/restore-signing-keychain.sh`): [`docs/signing.md`](docs/signing.md).

**Local secrets, not in the repository:** `~/.config/jevpaste/` holds the Jev gateway key (`env`), the signing
key and certificate (`signing/`) and the signing keychain password. Nothing there is ever committed, and the
app's diagnostic logs never contain payloads or credentials.

## Repository layout

One Swift package at the repository root. `SmartPasteCore` owns the seams as protocols; each adapter module
implements some of them; tests use in-memory fakes as the second adapter at every seam.

| module | responsibility | depends on |
|---|---|---|
| `SmartPasteCore` | Paste Attempt state machine, Candidate extraction, Pre-checks, Jev decision validation, history retention; declares `DecisionService`, `HistoryRepository`, `Clipboard`, `Hotkey`, `TargetResolver`, `Inserter` | nothing (no AppKit, networking or SQLite) |
| `JevGateway` | `DecisionService` adapter: Jev through the Vercel AI Gateway | `SmartPasteCore`, Foundation |
| `HistoryStore` | `HistoryRepository` adapter: SQLite | `SmartPasteCore` |
| `MacInterop` | `Clipboard`, `Hotkey`, `TargetResolver`, `Inserter` adapters: pasteboard, global shortcut, Accessibility | `SmartPasteCore`, AppKit / ApplicationServices |
| `JevPasteApp` | menu-bar shell, indicator, Candidate Chooser, wiring | all of the above |

Other paths: `Tests/<Module>Tests` (Swift Testing), `scripts/` (gate, bundle, hook and keychain scripts),
`Resources/AppIcon.png` (placeholder icon source), `docs/` (ADRs, quality gate, signing, worker briefs).
Module boundaries were decided in
[Choose native module boundaries and local quality checks](https://github.com/DanielMulec/jevpaste/issues/10).
