# Local Swift quality & testing controls — research findings

Ticket: [Find simple local Swift quality and testing controls](https://github.com/DanielMulec/jevpaste/issues/4) ·
Map: [Build Daniel's Jev-powered macOS smart-paste app](https://github.com/DanielMulec/jevpaste/issues/1)
Branch: `research/local-quality`, base commit `cd99be3`. Written by the research subagent for the parent's review.

> **Status: research only.** The 400-line maximum is an adopted hard requirement from Daniel, not a recommendation. Other numeric thresholds and stack choices below are recommendations for a later decision. Nothing was installed,
> nothing was provisioned, no CI or runner infrastructure was added, no app code was written. The only repo
> change from this session is this file.

Evidence labels used throughout:

- **Documented** — first-party docs/spec/proposal (Swift project, Apple, SwiftLint/SwiftFormat/swift-format
  projects) read or retrieved in this session; source listed in §7.
- **Observed** — a probe actually run on this Mac in this session; exact command and exit code in §8.
- **Inferred** — conclusion drawn from other evidence, not directly verified.
- **Unknown** — not established here; needs a later probe or a human decision.

Probes ran in scratch directories (`/tmp/jevprobe`, `/tmp/jevprobe2`, `/tmp/jevcheck`, `/tmp/jevwarn`,
`/tmp/lintprobe`) so the repository stayed untouched. No network installs: `npx`, `brew install`, etc. were
not run.

## 1. Question

Which native macOS/Swift stack and deterministic local tools can enforce modular readable code, a strict
400-line file ceiling, low complexity, duplication detection, formatting, compiler diagnostics,
unit/integration tests and useful static checks — with the smallest local check workflow, no hosted CI, and
no runner infrastructure?

## 2. Environment inventory (observed, read-only)

| Item | Command | Result |
|---|---|---|
| OS | `sw_vers` | macOS 26.6.2, build 25G83, arm64 |
| Xcode | `xcodebuild -version`; `xcode-select -p` | **Not installed.** `xcodebuild` errors: *"tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance"*. Active dir: `/Library/Developer/CommandLineTools`. `/Applications/Xcode*.app` absent |
| Swift | `swift --version` | Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`), target `arm64-apple-macosx26.0` |
| swift-format (Apple) | `/Library/Developer/CommandLineTools/usr/bin/swift-format --version`; `swift format --help` | **Present, 6.3.0**, inside the CLT toolchain. `swift format` subcommand works (`format`, `lint`, `dump-configuration`). Not on `PATH` as a bare command |
| SwiftLint (Homebrew) | `swiftlint version` | 0.63.3 (`/opt/homebrew/bin/swiftlint`) — present but crashes without a flag; see §4.5 |
| SwiftFormat (nicklockwood, Homebrew) | `swiftformat --version` | 0.61.1 (`/opt/homebrew/bin/swiftformat`) — different tool from Apple's swift-format |
| Other | `command -v` | Node 26.x, GNU Make 3.81, `/usr/bin/codesign`, `/usr/bin/plutil`, git |
| Absent tools | `command -v` | `periphery`, `jscpd`, `pmd`/`cpd`, `clang-tidy`, `scc`, `lizard`, `sonar-scanner`, `xcbeautify`, `xcpretty`, `tuist`, `xcodegen` |

Note: `node`/`npx` are installed, so a Node-based tool *could* be fetched on demand, but that is a network
dependency and was deliberately not exercised.

## 3. Stack routes and what each can enforce

Three routes are practical; none is decided here.

**Route A — Xcode project (app target + unit tests + UI tests).** Gives XCTest, Swift Testing, XCUITest and
`xcodebuild test` in one tool. Blocked today: **Xcode is not installed** (§2), so `xcodebuild` is
unavailable, and installing Xcode is an installation decision this ticket forbids taking. Documented:
XCUITest is the Apple-provided UI-testing path (UI Testing Bundle + `XCUIAutomation`/`XCUIApplication`), and
Apple's guidance is Swift Testing for unit tests plus XCTest/XCUIAutomation for UI tests [S10][S11].

**Route B — Swift Package only, built with the Command Line Tools.** Observed: a SwiftPM executable target
compiles and runs with AppKit, SwiftUI, ApplicationServices and CoreGraphics imports using only CLT
(`/tmp/jevprobe2`, §8) — so the app's system APIs are reachable without Xcode. `swift build` / `swift run`
work; tests via XCTest or Swift Testing do **not** (§4.2). A menu-bar `.app` bundle would have to be assembled
by hand (Info.plist + `codesign`); `codesign` and `plutil` exist, but **assembling and launching such a
bundle was not tested** — **Unknown**.

**Route C — hybrid (recommended shape, decision pending).** Keep a SwiftPM package as the logic core and a
thin app/bundle shell on top. This maximises the deterministic, Xcode-free surface: pure logic (history
store, active-item state machine, target-context prompt building, response validation, error mapping) lives
in package targets and is checkable with today's tools; system adapters stay behind protocols so they can be
faked. If an Xcode project is later added for the shell, the package is reused as a local package dependency
and the same core tests keep running.

## 4. Findings

### 4.1 Test frameworks: documented distribution vs observed failure

- **Documented**: Swift Testing ships in Swift.org toolchains 6.0+, in Xcode 16+, and in Apple's Command Line
  Tools for Xcode package 16.0+ as a *framework*; "built-in" copies are preferred over the package copy, which
  has documented caveats (builds the runtime, can fail to link/misbehave when mixed) [S5].
- **Observed (blocker)**: with CLT-only on this machine, a minimal package with `import Testing` fails to
  build — `error: no such module 'Testing'` — even with `swift test --enable-swift-testing` (flag exists:
  `swift test --help`). Adding an explicit framework search path
  (`-Xswiftc -F .../CommandLineTools/Library/Developer/Frameworks`) makes it *compile*, but the test bundle
  then dies at launch: `dlopen(...): Library not loaded: @rpath/Testing.framework/Versions/A/Testing`. Full
  transcript in §8.
- **Observed**: `import XCTest` fails identically (`no such module 'XCTest'`); there is no `XCTest.framework`
  under `/Library/Developer/CommandLineTools/Library/Developer/Frameworks/` (only `Testing.framework` and
  helpers). So XCTest is simply not part of a CLT-only install.
- **Inferred**: the documented CLT distribution of Swift Testing is present on disk but is not on the test
  bundle's runtime search path here; the failure is environment/toolchain-layout specific and its root cause
  was **not** determined. Practical consequences: (a) XCTest and Swift Testing did not run under the tested default configuration; this does not prove Xcode installation is the only remedy; (b) declaring `swiftlang/swift-testing` as a *package* dependency is the documented Xcode-free
  fallback [S5], but it needs network fetch + local build and carries documented caveats; (c) a
  framework-free checks executable works today (see §4.5 and §8) — verified to run and to exit non-zero on
  failure.

### 4.2 Deterministic formatting

- `swift format lint --strict` **exits 1** on unformatted files; without `--strict` it **exits 0** while still
  printing warnings (both observed). A gate therefore *must* pass `--strict`; the flag is documented as
  "Treat all findings as errors instead of warnings" in `swift format lint --help`.
- Apple's swift-format is the zero-install option: it ships in the CLT toolchain (6.3.0). Configuration is a
  JSON `.swift-format` file; documented keys include `version` (must be `1`), `lineLength` (default `100`),
  `indentation` (default `{ "spaces": 2 }`), `tabWidth` (default 8), `maximumBlankLines` (default 1), and a
  `rules` block [S1]. `swift format dump-configuration` prints the defaults (observed: 43 rules, lineLength
  100, 2-space indent).
- SwiftFormat 0.61.1 (a *different* tool) has `--lint` (**exit 1** observed) and a `--maxwidth` option; its
  rule list contains a `linebreakAtEndOfFile` rule but no file-length rule (observed via `swiftformat --rules`).
- **Recommendation (not policy)**: pick exactly one formatter as the source of truth to avoid two tools
  rewriting each other. Apple's `swift format` is the cheapest deterministic choice here because it needs no
  install; SwiftFormat stays optional.
- Neither formatter can enforce the 400-line ceiling (see §4.3) — formatting and file size are separate gates.

### 4.3 The 400-line ceiling and its counting caveats

SwiftLint's `file_length` is the only off-the-shelf line-count gate among the installed tools.

- **Documented defaults** [S6]: `warning: 400`, `error: 1000`, `ignore_comment_only_lines: false`;
  autocorrection *not* supported; kind `metrics`; analyzer rule `no`.
- **Observed**: with `file_length: {warning: 400, error: 400}` a file of exactly 400 logical lines passes and
  401 fails (`File should contain 400 lines or less: currently contains 401`). Both thresholds must be set to
  the ceiling, otherwise 400 is only a warning.
- **Observed counting semantics — the caveats that matter for "400 lines":**
  - With `ignore_comment_only_lines: true`, **comment-only and whitespace-only lines are excluded** — the
    tool's own diagnostic says "excluding comments and whitespaces". A file with 399 code lines plus 1 comment
    line and 5 blank lines (404 physical lines) *passed* a 400 ceiling; with the option set to `false` the
    same family of file failed at "currently contains 401". So: one setting changes the effective budget by
    the number of blank/comment lines.
  - `wc -l` and SwiftLint disagree on the last unterminated line: a file of 400 logical lines with **no
    trailing newline** reported `wc -l` = 399 but SwiftLint = 400. `wc -l` counts newline bytes; SwiftLint
    counts lines. **Do not make a shell `wc -l` script the ceiling authority** unless its off-by-one is
    handled and documented.
  - SwiftLint counts all lines spanned by multi-line tokens (documented in the rule's SwiftSyntax migration
    PR [S7]) — **Inferred** for this exact version; not re-verified locally.
- **Scope caveats still open (human decision)**: SwiftLint only measures `.swift` files; whether test files,
  scripts, docs/YAML, and generated files count against the ceiling must be decided, and if some are excluded
  the exclusion belongs in `excluded:` in `.swiftlint.yml`. The map's "do not game the limit with dense lines
  or meaningless fragmentation" is a review property, not something a tool can check.

### 4.4 Complexity, duplication, compiler and static checks

**Complexity — works headlessly.** `cyclomatic_complexity` fired correctly with `--disable-sourcekit`: a
function containing 4 `if`s, a `for`, a `while` and a `switch` reported `currently complexity is 8` and exit
code 2 (observed). Other built-in metrics rules available and not SourceKit-dependent: `function_body_length`,
`type_body_length`, `nesting`, `line_length`, `identifier_name` (observed in `swiftlint rules`). SwiftLint's
documented complexity defaults were not re-verified in this session — **Unknown**; the thresholds to adopt
should be set explicitly in the config rather than relying on defaults.

**Duplication — a real gap.** SwiftLint has no clone-detection rule; the only "duplicate" rules in 0.63.3 are
language-level ones (`duplicate_conditions`, `duplicate_enum_cases`, observed in `swiftlint rules`). Swift
clone detectors that exist are all extra tools:
- jscpd — vendor docs list `swift` / `.swift` among auto-detected formats and accept `--format swift` [S8];
  distributed via npm (`npx jscpd …`) with, per its site, prebuilt native binaries. Node 26.x is installed
  here, but the package itself is not installed and **was not run** — **Unknown** for real results/quality.
- PMD CPD — Swift support since PMD 5.3.7, `CPD: ✔` [S9]; needs a JRE (not installed).
- Simian/SonarQube are commercial or server-based; out of scope for a local single-Mac workflow.
- **Inferred**: because a clone detector must be added, duplication should be an *explicit, separately
  approved* step (pinned version, `min-tokens` threshold) rather than silently part of the daily gate; a
  home-grown heuristic script would be low-precision and is not recommended as a hard gate.

**Compiler diagnostics as checks — verified working with zero installs:**
- `swift build -Xswiftc -warnings-as-errors`: a warning-producing file built cleanly *without* the flag
  (2 warnings, exit 0) and failed *with* it (`error: initialization of variable 'unused' was never used …`,
  exit 1) — observed.
- `-Xswiftc -strict-concurrency=complete` and `-Xswiftc -enable-upcoming-feature ExistentialAny` are accepted
  by this toolchain (observed, build succeeded).
- Swift 6 language mode itself is a static check: the first probe of a framework-free checks runner failed to
  compile because a non-isolated global function mutated top-level `@MainActor` state ("main actor-isolated
  var 'failures' can not be mutated from a nonisolated context"; and a top-level variable cannot itself carry a
  global actor) — observed, fixed by keeping the counter in a value type.
- `--sanitize=address|thread|undefined|scudo` is a documented build/test flag for this SwiftPM
  (`swift build --help`; [S4]). Not run — **Unknown** for noise/utility here.
- Determinism flags exist and are documented in `swift build --help`: `--force-resolved-versions`,
  `--disable-automatic-resolution`, `--only-use-versions-from-resolved-file` (observed in help output).

**Xcode's Analyzer is not a Swift check.** Apple's static analyzer session documents the analyzer as finding
bugs "in Objective-C, C, and C++" [S12]; it does not analyze Swift. So "run Analyze" is not a useful Swift
gate even after installing Xcode. SwiftLint's *analyzer* rules (`capture_variable`, `explicit_self`,
`typesafe_array_init`, `unused_declaration`, `unused_import` — observed) require
`swiftlint analyze --compiler-log-path` from a clean compiler log, and the SwiftLint README's example pipeline
is `xcodebuild`-based [S3]; whether a CLT/SwiftPM build log can feed it is **Unknown**.

**SwiftLint on this machine needs a flag.** Plain `swiftlint lint` crashes here regardless of which rules are
enabled: `SourceKittenFramework/library_wrapper.swift:58: Fatal error: Loading
sourcekitdInProc.framework/Versions/A/sourcekitdInProc failed`, exit 133, even with only `file_length` enabled
(observed). The framework file *does* exist and `dlopen`s successfully from another process (observed), so the
cause is inside SwiftLint/SourceKitten's toolchain resolution and is **Unknown**; note the installed binary's
rpath references an Xcode toolchain path (`/Applications/Xcode.app/.../swift-6.2/macosx`) and there is no Xcode
here. **Verified workaround**: `swiftlint lint --disable-sourcekit --strict --quiet --no-cache` runs fine
(exit 0 clean, exit 2 on violations). `--disable-sourcekit` is documented in `swiftlint lint --help` as "Do not
dynamically load SourceKit at runtime. Skip and report rules that require it" — in 0.63.3 exactly 13 rules
declare `uses sourcekit` (observed via the `swiftlint rules` table): `capture_variable`, `explicit_self`,
`file_types_order`, `indentation_width`, `literal_expression_end_indentation`, `multiline_function_chains`,
`multiline_parameters_brackets`, `statement_position`, `typesafe_array_init`, `unused_declaration`,
`unused_import`, `vertical_whitespace_closing_braces`, `vertical_whitespace_opening_braces`. None of the rules
needed for the ceiling/complexity/naming gates are in that list. Installing Xcode would presumably remove the
need for the flag, but that is an installation decision.

### 4.5 Modularity and test seams

- **Access control for seams**: SE-0386 introduced `package` (implemented in Swift 5.9) — visible across
  targets in the same Swift package but not to outside clients; SwiftPM supplies the package name, and a
  target can opt out with `packageAccess: false` (useful for black-box tests) [S13]. Combined with
  `@testable import` for test targets, this lets internals stay non-public while remaining testable.
- **Target-dependency discipline**: `swift build --explicit-target-dependency-import-check=<value>` exists in
  this toolchain (observed in `swift build --help`), which can flag targets importing what they did not
  declare — a structural check for "no accidental reach-through". Accepted values were not verified —
  **Unknown**.
- **APIs that must sit behind ports** (they are process-global and permission-gated, so they cannot be
  exercised in a hermetic test): `NSPasteboard` (system-wide clipboard, must be preserved per the map),
  `CGEventTap` (hotkey capture; keyboard event taps need Accessibility trust), and `AXIsProcessTrusted`/
  `AXUIElement` (focused target/app context). All four are importable and compile in this environment
  (observed, `/tmp/jevprobe2`). Actual permission prompts and behaviour under TCC were **not** tested — the app
  would have to be bundled and granted permissions, which is outside this ticket. **Inferred**: the pure logic
  must not reference these types directly; inject narrowed protocols (Clipboard, Hotkey, FocusInspector) so the
  deterministic gates stay runnable and hermetic, and so a fake is possible in tests.
- **Bundle personality**: a background/menu-bar app is largely an Info.plist/bundle concern (LSUIElement-style
  agent behaviour, no Dock icon). Apple's documentation pages for these keys are JavaScript-rendered and could
  not be quoted from source in this session — treated as **Documented (URL only, not verified here)** [S14].
  Whatever the shell turns out to be, a thin shell keeps the ceiling and complexity rules meaningful.
- Suggested shape (recommendation, not architecture): `Core` (pure domain + state), `Interop` (clipboard,
  hotkey, focus), `JevClient` (HTTP + response validation, behind a protocol), `Shell` (SwiftUI/AppKit,
  bundle). The map's rule that diagnostic logs must never contain payloads or credentials is a review
  constraint, not something a linter enforces.

### 4.6 Recommended minimal single local verification command

One entry point, no network, no Xcode, no runner: **`make check`** (GNU Make 3.81 present), where `make`
invokes `scripts/check.sh` with fail-fast steps in this order:

| # | Command | Enforces | Status today |
|---|---|---|---|
| 1 | `swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete` | compiler diagnostics, concurrency correctness, modular target graph | **Verified working** |
| 2 | `swift format lint --strict -r Sources Packages` (or `/Library/Developer/CommandLineTools/usr/bin/swift-format lint --strict -r …`) | deterministic formatting | **Verified working** (`--strict` required) |
| 3 | `swiftlint lint --disable-sourcekit --strict --quiet --no-cache` | 400-line ceiling, complexity, body length, nesting, naming | **Verified working with the flag** |
| 4 | `swift run Checks` (framework-free assertions, exit non-zero on failure) — replaced later by `swift test` if Xcode is installed | unit/integration tests that need no system services | **Verified working**; `swift test` **blocked today** (§4.1) |
| 5 | *(optional, separate target)* `npx jscpd@<pinned> Sources --format swift --min-tokens <N>` | duplication | **Not installed, not run** — needs an explicit decision |

Example ceiling/complexity config (thresholds are proposals for the human decision, not adopted policy):

```yaml
# .swiftlint.yml
only_rules: [file_length, function_body_length, type_body_length, cyclomatic_complexity, nesting, line_length, identifier_name]
file_length:
  warning: 400        # same as error so 400 is a hard ceiling, not advice
  error: 400
  ignore_comment_only_lines: false  # count comments and blank lines; preserve the owner's hard ceiling
cyclomatic_complexity:
  warning: 10
  error: 10
function_body_length: {warning: 60, error: 60}
type_body_length: {warning: 250, error: 250}
nesting: {type_level: 2, function_level: 2}
line_length: {warning: 120, error: 120}
```

Exit-code contract that the single command must preserve (all observed): clean run 0; formatting violation 1
(`--strict`); SwiftLint violation 2 (`--strict`); checks failure 1; SwiftLint without `--disable-sourcekit` 133
(crash) — which is exactly why the flag is mandatory until Xcode exists.

## 5. Decision implications (for the parent/human, not decided here)

1. **Choose test/toolchain setup.** Xcode provides the standard XCTest/XCUITest and xcodebuild route. The observed Swift Testing framework loader failure does not establish that Xcode is mandatory: resolve or explicitly rule out framework search/runtime paths and supported toolchain alternatives before recommending a custom checks harness. Whether Xcode resolves the SwiftLint failure remains untested.
2. **Stack**: SwiftPM-only (Route B) vs hybrid (Route C) vs Xcode project (Route A). Route C preserves the most
   testable surface today; Route A provides Apple's standard XCUITest path, but is not proven necessary for every form of UI/acceptance automation.
3. **Ceiling scope and counting mode**: which paths the 400-line limit covers (app sources only? tests?
   scripts?) and whether `ignore_comment_only_lines` is on (it changes the effective budget by blank/comment
   lines).
4. **Numeric thresholds**: 400 lines is already mandatory. Complexity 10, body lengths, and line length 100 versus 120 remain recommendations.
5. **Duplication tooling**: adopt a pinned `jscpd` (or PMD CPD with a JRE) as a separate, approved step, or
   accept the gap in v1 and rely on review.
6. **Acceptance suite form**: XCUITest (needs Xcode + UI-testing permission) vs a scripted smoke harness plus a
   manual checklist for the real-app acceptance the map requires.

## 6. Limitations and unknowns

- XCTest/Swift Testing/XCUITest could not be exercised at all (no Xcode). The root cause of the Swift Testing
  runtime-load failure and of the SwiftLint SourceKit crash is **Unknown**; only the workarounds were verified.
- Duplication detection was never run; jscpd's Swift tokenization quality on real Swift code is **Unknown**.
- Nothing about the app bundle was verified: no `.app` was assembled, no TCC/Accessibility permission flow was
  exercised, no menu-bar behaviour was tested.
- Apple documentation pages (`MenuBarExtra`, `LSUIElement`, Testing/XCTest pages) are JavaScript-rendered and
  could not be quoted from source; those points rest on the URLs in §7 and are marked as such.
- SwiftLint's complexity defaults, `--explicit-target-dependency-import-check` values, sanitizer behaviour and
  multi-line-token line counting were not verified.
- Findings are pinned to the versions in §2; SwiftLint/SwiftFormat/Swift come from Homebrew and the CLT and will
  drift. A future session should re-run §8.
- This file is written to satisfy its own ceiling: it is under 400 lines by both `wc -l` and logical-line count
  (verified at commit time; see §8).

## 7. Sources

- [S1] swift-format, *Configuration* — https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md
- [S2] swift-format, *Rule documentation* — https://github.com/swiftlang/swift-format/blob/main/Documentation/RuleDocumentation.md
- [S3] SwiftLint, *README* (SwiftSyntax/SourceKit split, toolchain resolution order, config keys, `analyze`) — https://github.com/realm/SwiftLint/blob/main/README.md
- [S4] SwiftPM, *swift test* and *swift build* docs — https://docs.swift.org/latest/documentation/packagemanagerdocs/swifttest/ ; local `swift build --help`, `swift test --help`, `swift format lint --help`
- [S5] swift-testing, *Obtaining Swift Testing (Distributions)* — https://github.com/swiftlang/swift-testing/blob/main/Documentation/Distributions.md
- [S6] SwiftLint rule reference, *file_length* (defaults 400/1000, `ignore_comment_only_lines: false`, no autocorrection) — https://realm.github.io/SwiftLint/file_length.html
- [S7] SwiftLint PR #6100, *Migrate FileLengthRule from SourceKit to SwiftSyntax* (multi-line tokens, comment/whitespace exclusion) — https://github.com/realm/SwiftLint/pull/6100
- [S8] jscpd, *Supported formats* (`swift`, `.swift`, auto-detected) — https://jscpd.dev/getting-started/supported-formats and https://github.com/kucherenko/jscpd/blob/master/FORMATS.md
- [S9] PMD, *Swift support* (`SwiftLanguageModule`, since PMD 5.3.7, CPD ✔) — https://docs.pmd-code.org/pmd-doc-7.27.0/pmd_languages_swift.html
- [S10] Apple, *Testing* / *Adding tests to your Xcode project* — https://developer.apple.com/documentation/xcode/testing and https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project
- [S11] Apple, *User Interface Testing* (UI Testing Bundle, XCUIAutomation, permission prompts) — https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/09-ui_testing.html
- [S12] Apple, *Detect bugs early with the static analyzer* (WWDC21 session 10202; analyzer covers Objective-C, C, C++) — https://developer.apple.com/videos/play/wwdc2021/10202/
- [S13] Swift Evolution SE-0386, *New access modifier: package* (implemented Swift 5.9) — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md
- [S14] Apple, *MenuBarExtra* and Information Property List *LSUIElement* (pages not machine-readable this session) — https://developer.apple.com/documentation/swiftui/menubarextra and https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement

## 8. Validation log (exact probes and observed results)

| Probe | Command (abridged) | Observed |
|---|---|---|
| Tool inventory | `sw_vers`, `xcodebuild -version`, `swift --version`, `swiftlint version`, `swiftformat --version`, `command -v …` | see §2; `xcodebuild` refuses (CLT only) |
| CLT SDK coverage | SwiftPM executable importing AppKit + SwiftUI + ApplicationServices + CoreGraphics, `swift build` then `swift run` | Build complete; ran and printed `ok` |
| Warnings as errors | same target with an unused variable: `swift build` vs `swift build -Xswiftc -warnings-as-errors` | 2 warnings / exit 0 → promoted to error / exit 1 |
| Extra compiler flags | `swift build -Xswiftc -strict-concurrency=complete -Xswiftc -enable-upcoming-feature -Xswiftc ExistentialAny` | accepted, build complete |
| Swift Testing availability | minimal package, `import Testing`, `swift test` and `swift test --enable-swift-testing` | `error: no such module 'Testing'` |
| Swift Testing with search path | same + `-Xswiftc -F …/CommandLineTools/Library/Developer/Frameworks` (and `-Xlinker -F …`) | compiled; then `dlopen … Library not loaded: @rpath/Testing.framework/Versions/A/Testing` |
| XCTest availability | `import XCTest`, `swift test` | `error: no such module 'XCTest'`; no `XCTest.framework` under CLT |
| Framework-free checks runner | executable target with a value-type checker, `swift run Checks` | printed `ok`/`FAIL`, reported `1 failure(s)`, exit 1 |
| swift-format gate | `swift format lint --strict -r Sources` vs without `--strict` | exit 1 vs exit 0 (warning printed) |
| swift-format defaults | `swift format dump-configuration` | version 1, lineLength 100, 2-space indent, 43 rules, no file-length rule |
| SwiftFormat gate | `swiftformat --lint Sources` | exit 1 |
| SwiftLint crash | `swiftlint lint --no-cache <file>` (with `only_rules: [file_length]`) | `Fatal error: Loading sourcekitdInProc.framework/Versions/A/sourcekitdInProc failed`, exit 133 |
| SwiftLint workaround | `swiftlint lint --disable-sourcekit --no-cache --quiet …` | runs; clean 0, violation 2 |
| SourceKit availability | `python3 -c "ctypes.CDLL('…/sourcekitdInProc')"`; `ls` the framework versions dir | `dlopen OK`; binary present |
| Ceiling semantics | files of 400/401 lines, comment-only and blank lines, missing trailing newline; `file_length: {warning: 400, error: 400}` with `ignore_comment_only_lines` true/false; `wc -l` | ≤400 pass, 401 fail; comments+blanks excluded only when the option is true; `wc -l` 399 vs SwiftLint 400 on the unterminated file |
| Complexity rule | function with 4×`if` + `for` + `while` + `switch`, `cyclomatic_complexity: {warning: 3, error: 3}` | `currently complexity is 8`, error, exit 2 — with `--disable-sourcekit` |
| Warning vs error gating | `file_length` warning-only threshold with and without `--strict` | exit 0 vs exit 2 |
| Rule inventory | `swiftlint rules` | 8-column table incl. `opt-in`, `analyzer`, `uses sourcekit`; 13 rules use SourceKit; analyzer rules listed in §4.4 |
