# Quality gate — `make check`

The entire local CI of jevpaste, decided in
[Choose native module boundaries and local quality checks](https://github.com/DanielMulec/jevpaste/issues/10)
and [ADR 0001](adr/0001-clt-only-swiftpm-app-with-hand-assembled-signed-bundle.md). Offline, fail-fast, run by
the pre-commit hook. Command Line Tools only — no Xcode. Tool versions at the time of writing: Swift 6.3.3,
swift-format 6.3.0 (CLT), SwiftLint 0.63.3, jscpd 5.3.1 (pinned in `package.json`), Periphery 3.8.0,
Swift Testing 6.3.2 (package dependency, pinned exactly).

## Steps and exit-code contract

`make` stops at the first step that exits non-zero and itself exits 2. Every exit code below was observed on
a deliberate violation (see the proofs further down).

| # | make target | command | clean | violation |
|---|---|---|---|---|
| 1 | `build-strict` | `scripts/build-strict.sh` (see below) | 0 | 1 (compiler error, or undeclared import in one of our targets) |
| 2 | `format-lint` | `swift format lint --strict -r Sources Tests` | 0 | 1 |
| 3 | `lint` | `TOOLCHAIN_DIR=/Library/Developer/CommandLineTools swiftlint lint --strict --quiet --no-cache` | 0 | 2 |
| 4 | `duplication` | `npx --no-install jscpd --config .jscpd.json` | 0 | 1 |
| 5 | `test` | `swift test` + the two CLT linker flags from ADR 0001 | 0 | 1 |
| 6 | `dead-code` | `periphery scan` (config `.periphery.yml`, `strict: true`) | 0 | 1 |
| 7 | `line-counts` | `scripts/check-line-counts.sh` | 0 | 1 |

Other targets: `make format` (swift-format in place), `make acceptance` (stub; the real-app suite is never part
of `make check`), `make app` (`scripts/make-app.sh`), `make install` (copies to `~/Applications/JevPaste.app`).

## Deviations from the resolution's literal commands, and why

Both were approved by the supervisor before being adopted.

### Step 1 — the import check runs as `warn`, filtered to our targets

`swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete -Xswiftc -enable-upcoming-feature
-Xswiftc ExistentialAny --explicit-target-dependency-import-check error` fails on the clean skeleton: SwiftPM
applies the import check to every package in the graph, and the swift-testing / swift-syntax dependencies
violate it themselves (`Target TestingMacros imports another target (SwiftSyntaxBuilder) …`,
`Target SwiftSyntaxMacrosTestSupport imports another target (Testing) …`). `--product JevPasteApp` does not
scope it.

`scripts/build-strict.sh` runs the same build with `--explicit-target-dependency-import-check warn` and exits 1
if any `Target X imports another target` line names one of our targets (every directory under `Sources/` and
`Tests/`). Dependency packages' own warnings are ignored. `-warnings-as-errors` still applies to our code.

**Caveat:** SwiftPM reports only the first undeclared import per target, and which one it reports varies
between runs. Fixing one may reveal the next.

### Step 3 — SwiftLint loads SourceKit from the CLT instead of `--disable-sourcekit`

Root cause of the SourceKit crash noted in the local-quality research: SwiftLint looks for `sourcekitdInProc`
in an Xcode toolchain. Without Xcode, plain `swiftlint lint` aborts
(`Loading sourcekitdInProc.framework/Versions/A/sourcekitdInProc failed`, exit 133). Setting
`TOOLCHAIN_DIR=/Library/Developer/CommandLineTools` makes it load the CLT's own framework.

`--disable-sourcekit` is not enough: SwiftLint 0.63.3 then skips `custom_rules` entirely ("requires SourceKit
and SourceKit access is prohibited"), and `execution_mode: swiftsyntax` aborts because the custom-rule matcher
still asks SourceKit for the syntax map. The three custom rules below need SourceKit.

SourceKit-dependent rules: 13 rules declare SourceKit use. Under `swiftlint lint`, only one is enabled here:
`statement_position` (a default rule, consistent with swift-format's output, proven below). Of the others,
`capture_variable`, `explicit_self`, `typesafe_array_init`, `unused_declaration` and `unused_import` are
*analyzer* rules that run only under `swiftlint analyze` with a compiler log, so they do not run in `make check`;
dead code and unused declarations are Periphery's job. The remaining whitespace/ordering rules
(`file_types_order`, `indentation_width`, `literal_expression_end_indentation`, `multiline_function_chains`,
`multiline_parameters_brackets`, `vertical_whitespace_closing_braces`, `vertical_whitespace_opening_braces`)
are opt-in and stay off: swift-format is the only formatter.

`trailing_comma` is disabled because it contradicts swift-format, which adds trailing commas to multi-line
collections.

## SwiftLint configuration (`.swiftlint.yml`)

`included: [Sources, Tests]`. Every configured rule has `error` severity, and `--strict` promotes anything left.

| rule | setting |
|---|---|
| `file_length` | 400/400, `ignore_comment_only_lines: false` — tests, comments and blank lines count |
| `cyclomatic_complexity` | 10 |
| `function_body_length` | 60 |
| `type_body_length` | 250 |
| `line_length` | 120 |
| `nesting` | type level 2, function level 2 |
| `identifier_name` | minimum length 3 |
| `force_cast`, `force_try`, `force_unwrapping`, `implicitly_unwrapped_optional` | error |
| `todo`, `fatal_error_message` | error |
| `no_print` (custom) | regex `(?<![\w.])print\s*\(`, comments and strings excluded |
| `no_dynamic_any` (custom) | regex `\b(Any\|AnyObject)\b`, comments and strings excluded; allowlist `excluded: []` |
| `core_import_ban` (custom) | only `Sources/SmartPasteCore/**`: `import AppKit\|ApplicationServices\|SQLite3\|Cocoa\|SwiftUI` (also `@preconcurrency import`, `import class …`) or `URLSession` |

`no_dynamic_any` allowlist: add a path regex to `excluded` only with a comment giving the reason.

## Proof that every SwiftLint rule fires

Method: for each rule, a temporary file `Sources/SmartPasteCore/ProofViolation.swift` (or another module where
stated) was created, `make lint`'s command was run, the diagnostic for that rule captured, and the file deleted.
Every positive case exited 2 with exactly one diagnostic for the rule under test. Negative cases exited 0.

| rule | violating content | diagnostic |
|---|---|---|
| `file_length` | 401 lines (1 declaration + 400 comment lines) | `ProofViolation.swift:401:1: error: File Length Violation: File should contain 400 lines or less: currently contains 401 (file_length)` |
| `cyclomatic_complexity` | function with 11 `if`s (10 `if`s passes) | `ProofViolation.swift:1:1: error: Cyclomatic Complexity Violation: Function should have complexity 10 or less; currently complexity is 11 (cyclomatic_complexity)` |
| `function_body_length` | function with 62 body lines | `ProofViolation.swift:1:1: error: Function Body Length Violation: Function body should span 60 lines or less excluding comments and whitespace: currently spans 62 lines (function_body_length)` |
| `type_body_length` | struct with 251 properties | `ProofViolation.swift:1:1: error: Type Body Length Violation: Struct body should span 250 lines or less excluding comments and whitespace: currently spans 251 lines (type_body_length)` |
| `line_length` | 127-character line | `ProofViolation.swift:1:1: error: Line Length Violation: Line should be 120 characters or less; currently it has 127 characters (line_length)` |
| `nesting` (type) | `enum` nested 3 deep | `ProofViolation.swift:4:13: error: Nesting Violation: Types should be nested at most 2 levels deep (nesting)` |
| `nesting` (function) | `func` nested 3 deep | `ProofViolation.swift:4:13: error: Nesting Violation: Functions should be nested at most 2 levels deep (nesting)` |
| `identifier_name` | `let ab = 1` | `ProofViolation.swift:1:5: error: Identifier Name Violation: Variable name 'ab' should be between 3 and 40 characters long (identifier_name)` |
| `force_cast` | `(1 as Any) as! Int` | `ProofViolation.swift:1:30: error: Force Cast Violation: Force casts should be avoided (force_cast)` |
| `force_try` | `try! risky()` | `ProofViolation.swift:2:13: error: Force Try Violation: Force tries should be avoided (force_try)` |
| `force_unwrapping` | `Int("1")!` | `ProofViolation.swift:1:22: error: Force Unwrapping Violation: Force unwrapping should be avoided (force_unwrapping)` |
| `implicitly_unwrapped_optional` | `var label: String!` | `ProofViolation.swift:1:12: error: Implicitly Unwrapped Optional Violation: Implicitly unwrapped optionals should be avoided when possible (implicitly_unwrapped_optional)` |
| `todo` | `// TODO: remove` | `ProofViolation.swift:1:4: error: Todo Violation: TODOs should be resolved (remove) (todo)` |
| `fatal_error_message` | `fatalError()` | `ProofViolation.swift:2:5: error: Fatal Error Message Violation: A fatalError call should have a message (fatal_error_message)` |
| `statement_position` | `}` and `else {` on separate lines | `ProofViolation.swift:4:5: error: Statement Position Violation: Else and catch should be on the same line, one space after the previous declaration (statement_position)` |
| `no_print` | `print("hello")` | `ProofViolation.swift:2:5: error: No print Violation: Do not use print(); log through the Log module, which never records payloads. (no_print)` |
| `no_dynamic_any` (`Any`) | `let anything: Any = 1` | `ProofViolation.swift:1:15: error: No Any or AnyObject Violation: Do not use Any or AnyObject as a type; add the file to this rule's allowlist only with a reason. (no_dynamic_any)` |
| `no_dynamic_any` (`AnyObject`) | `let reference: AnyObject? = nil` | `ProofViolation.swift:1:16: error: No Any or AnyObject Violation: … (no_dynamic_any)` (same message) |
| `no_dynamic_any` negative | `(any Clipboard)?`, `AnyHashable`, `Any` in a comment and in a string | no diagnostic, exit 0 |
| `core_import_ban` (import) | `import AppKit` in Core | `ProofViolation.swift:1:1: error: Core stays platform-free Violation: SmartPasteCore must not import AppKit, ApplicationServices, SQLite3, Cocoa or SwiftUI, or use URLSession. (core_import_ban)` |
| `core_import_ban` (URLSession) | `URLSession.shared` in Core | `ProofViolation.swift:1:15: error: Core stays platform-free Violation: … (core_import_ban)` (same message) |
| `core_import_ban` negative | `import AppKit` in `Sources/MacInterop`, `URLSession.shared` in `Sources/JevGateway` | no diagnostic, exit 0 |

Paths in the diagnostics are shortened from `Sources/SmartPasteCore/ProofViolation.swift`.

## Proof that every other step fails

| step | violating content | diagnostic | exit |
|---|---|---|---|
| 1 warnings-as-errors | `let unusedValue = 1` in a function | `error: initialization of immutable value 'unusedValue' was never used; … [#no-usage]` | 1 |
| 1 ExistentialAny | `func accept(proof: Proof)` with `protocol Proof {}` | `error: use of protocol 'Proof' as a type must be written 'any Proof'; … [#ExistentialAny]` | 1 |
| 1 strict concurrency | global `let sharedCounter = Counter()` of a non-`Sendable` class | `error: let 'sharedCounter' is not concurrency-safe because non-'Sendable' type 'Counter' may have shared mutable state [#MutableGlobalVariable]` | 1 |
| 1 import check | `import HistoryStore` in `Sources/JevGateway` (undeclared) | `warning: Target JevGateway imports another target (HistoryStore) in the package without declaring it a dependency.` → script prints `error: undeclared target imports in our modules …` | 1 |
| 2 swift-format | `let  spaced = 1` | `ProofViolation.swift:1:4: error: [Spacing] remove 1 space` | 1 |
| 4 jscpd | two 11-line Core functions differing only in name (56 tokens) | `Found 1 clones.` / `ERROR: jscpd found too many duplicates (7.9%) over threshold (0.0%)` | 1 |
| 5 swift test | `#expect(PasteAttemptState.idle.isFinished)` | `✘ Test deliberatelyFailing() recorded an issue at ProofFailingTests.swift:5:5: Expectation failed: …` | 1 |
| 6 periphery | `struct UnusedProofType {}` in Core | `ProofViolation.swift:1:8: warning: Unused struct 'UnusedProofType'` / `Error: Found 1 issue.` | 1 |
| 7 line guard | 401-line `.md`; 401 lines without a trailing newline | `tmp-over.md:401: error: 401 lines exceed the 400-line ceiling` (a 400-line file without trailing newline passes) | 1 |

## Tool notes

- **jscpd** skips files below `minTokens` (50), so the "Files analyzed" count is lower than the file count.
  `threshold: 0` plus `exitCode: 1` makes any clone fail.
- **Periphery** builds the test targets too, so `.periphery.yml` repeats the two CLT linker flags as
  `build_arguments`. `retain_assign_only_property_types: [NSStatusItem]` keeps the status item, which must be
  held for its lifetime but is never read. Public declarations that only tests use are not reported.
  `retain_encodable_properties: true` keeps properties of `Encodable` types (JevGateway request bodies), which
  only the synthesized `encode(to:)` reads.
- **Line guard** covers every non-Swift text file tracked or untracked-but-not-ignored by git, excluding
  `frames/`, `spikes/`, `node_modules/`, `.build/`, `build/` and `video.mp4`. It counts like SwiftLint: a final
  line without a trailing newline counts.
