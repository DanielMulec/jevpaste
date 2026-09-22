# Brief — ticket #15: Scaffold the package, quality gate and signed bundle

You are a fresh Pi session (`anthropic/claude-opus-5-5:medium`) in worktree
`~/.pi/worktrees/jevpaste/scaffold`, branch `scaffold` (forked from `main`). Your supervisor is
the Pi session with intercom id **`01a0c5fd`** (cwd `/Users/danielmulec/Projekte/experiments/jevpaste`).
Use exactly that id. Ignore any other pi in that cwd. Daniel (owner) is present but speaks through
the supervisor; ask the supervisor, not Daniel.

Communication protocol:
- `intercom send 01a0c5fd` a one-line progress note after **every numbered step** below.
- `intercom ask 01a0c5fd` (blocking) at each **GATE** — do not continue past a gate until answered.
- Anything unexpected (tool crash, install prompt, design fork not covered here) → `ask` first.
- Answer asks you receive with `intercom reply`, never `send`.

## Read first (in this order)
1. `gh issue view 10 --comments` — the architecture resolution. It is the spec. Do not re-decide.
2. `docs/adr/0001-clt-only-swiftpm-app-with-hand-assembled-signed-bundle.md`.
3. `gh issue view 15` — the ticket you are executing; its "done when" is your acceptance.
4. `gh issue view 1` — the map; read **Notes** for the hard rules (400 lines/file **including tests,
   comments and blank lines**; no hosted CI; no secrets in source; refer to issues by title).
5. `CONTEXT.md` — use its vocabulary in names (Paste Attempt, Active Item, Bound Target, Candidate…).
6. For the bundle script: `git show origin/spike/signing-identity:spikes/macos-probe/scripts/make-signed-app.sh`.

## Rules
- CLT only. Never install or require Xcode. Swift 6 language mode.
- Approved installs: `npm` packages pinned in `package.json` (jscpd), `brew install periphery`. Nothing else
  without asking.
- No app behaviour in this ticket — empty modules with one trivial public type each, so the graph,
  the gate and the bundle are real. No Jev calls, no network at runtime, never read `~/.config/jevpaste/env`.
- Every file, including tests, scripts, configs: ≤ 400 lines. Descriptive names, no abbreviations.
- Sign with identity `jevpaste-dev`. It shows `CSSMERR_TP_NOT_TRUSTED` in `security find-identity` —
  that is expected and it signs fine (`security find-identity -v` lists 0; use it without `-v`).
- Bundle id `com.jevpaste.JevPaste`, app name `JevPaste`, install path `~/Applications/JevPaste.app`
  (constant path; no sudo). `LSUIElement` true. Do **not** touch `~/Desktop/*Probe.app`.
- Commit small, descriptive commits on `scaffold`. Push after each gate passes.

## Steps

1. **Package.swift** with targets `SmartPasteCore`, `JevGateway`, `HistoryStore`, `MacInterop`,
   `JevPasteApp` (executable) and a test target per library module (`<Module>Tests`) using Swift
   Testing via the `swiftlang/swift-testing` package dependency. Dependency graph exactly as in the
   resolution table (Core depends on nothing; app depends on all). Each module: one small public type
   that proves the seam (e.g. Core declares the six protocols with doc comments and one `PasteAttemptState`
   enum stub; adapters declare an empty type conforming to their protocol). `swift build` green.
2. **Makefile** — `make check` runs, fail-fast, in this order:
   1. `swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete -Xswiftc -enable-upcoming-feature -Xswiftc ExistentialAny --explicit-target-dependency-import-check error`
   2. `swift format lint --strict -r Sources Tests` (Apple swift-format from the CLT; `.swift-format` with lineLength 120, 4-space indent)
   3. `swiftlint lint --disable-sourcekit --strict --quiet --no-cache`
   4. `npx --no-install jscpd` with `.jscpd.json` (`format: swift`, `min-tokens` 50, `threshold: 0`, paths `Sources Tests`)
   5. `swift test -Xlinker -L/Library/Developer/CommandLineTools/Library/Developer/usr/lib -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib`
   6. `periphery scan` (config `.periphery.yml`; targets = all library modules; retain public API of the executable's entry)
   7. a line-count guard for non-Swift text files (scripts, Makefile, YAML/JSON/MD under the repo, excluding `frames/`, `video.mp4`, `spikes/`, `node_modules/`, `.build/`) — 400 lines, counting like SwiftLint (physical lines; handle the no-trailing-newline off-by-one).
   Also `make acceptance` (stub that prints what it will run and exits 0), `make app` (build + assemble + sign), `make install` (copy to `~/Applications/JevPaste.app`), `make format` (swift-format in place).
   **GATE A**: `make check` green on the skeleton. Ask with the exact output summary.
3. **`.swiftlint.yml`** — all rules from the resolution as **errors**: `file_length` 400/400 with
   `ignore_comment_only_lines: false`; `cyclomatic_complexity` 10; `function_body_length` 60;
   `type_body_length` 250; `line_length` 120; `nesting` type 2 / function 2; `identifier_name` min 3;
   `force_cast`, `force_try`, `force_unwrapping`, `implicitly_unwrapped_optional`; `todo`;
   `fatal_error_message`; custom rules: `no_print` (ban `print(`), `no_dynamic_any` (ban `Any`/`AnyObject`
   as types, with an explicit `excluded` allowlist that is empty for now), `core_import_ban` (in
   `Sources/SmartPasteCore/**`: no `import AppKit|ApplicationServices|SQLite3|Cocoa|SwiftUI` and no
   `URLSession`). `included: [Sources, Tests]`.
   **Prove every rule fires once**: for each rule, create a temporary violating file, run the linter,
   capture the one-line diagnostic, delete the file. Record the table (rule → diagnostic) in
   `docs/quality-gate.md` (≤ 400 lines) along with the exit-code contract of every `make check` step.
   **GATE B**: ask with the path of `docs/quality-gate.md`.
4. **Pre-commit hook**: `scripts/install-hooks.sh` installs a `.git/hooks/pre-commit` that runs
   `make check`. Document in README. Run it once to prove it blocks a violating commit, then that a clean
   commit passes.
5. **Bundle**: `scripts/make-app.sh` — release build, `Info.plist` written by the script
   (`CFBundleIdentifier com.jevpaste.JevPaste`, `LSUIElement`, `NSAccessibilityUsageDescription` with an
   honest one-sentence text), icon via `iconutil` from a placeholder `.iconset` you generate with `sips`
   from a single simple PNG (a plain rounded square is fine — no design work), `codesign --force --sign
   jevpaste-dev`. `JevPasteApp` main: AppKit `NSApplication` with an `NSStatusItem` showing an SF Symbol
   (`doc.on.clipboard`) and a menu with only "Quit". No other behaviour. `make install`, launch it with
   `open ~/Applications/JevPaste.app`, confirm the status item is visible via `codesign -dv` + process
   running + a screenshot is NOT required — instead report `codesign -d -r-` and `pgrep`. Quit it.
   **GATE C**: ask with cdhash + designated requirement + pgrep evidence.
6. **README**: replace the current README's contents with: what jevpaste is (one paragraph, keep the
   existing video/frames as behavioural evidence links), prerequisites (CLT, Homebrew swiftlint + periphery,
   Node for jscpd), `make check` / `make app` / `make install`, the signing-identity note (link ADR 0001
   and issue #13), and a "Repository layout" section with the five modules in one table.
   Keep it ≤ 150 lines.
7. Final: `make check` green from a clean `rm -rf .build node_modules && npm ci`. Push. `intercom ask`
   the supervisor with the final commit sha and a ≤ 15-line summary; then end your turn.

## Report format for progress sends
`step N done — <one line of fact>` (no adjectives). For gates: the evidence asked for, nothing else.
