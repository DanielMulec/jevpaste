# 0001 — CLT-only SwiftPM app with a hand-assembled, identity-signed bundle

**Status:** accepted · **Date:** 2026-09-22 · **Ticket:** [Choose native module boundaries and local quality checks](https://github.com/DanielMulec/jevpaste/issues/10)

## Context

jevpaste is a personal macOS menu-bar app built almost entirely by agents on one Mac. The Mac has the
Command Line Tools (Swift 6.3.3) but no Xcode. Every platform question so far — building against AppKit,
assembling a `.app`, code-signing, obtaining and keeping the Accessibility grant — was answered without
Xcode. The one open question was tests: XCTest is absent from the CLT, and the research ticket found Swift
Testing unable to load under the default configuration.

Installing Xcode (~15 GB) would give an Xcode project, XCTest/XCUITest and `xcodebuild`, at the cost of a
second build system, Interface Builder/asset-catalog artefacts that agents handle poorly, and a heavy
dependency for a tiny app.

## Decision

- The app is a **single Swift package** (`Package.swift` at the repo root) built with the Command Line
  Tools only. Xcode is not a dependency and must not become one by accident.
- The `.app` bundle is **assembled by a script** (`Info.plist` written by the script, executable copied
  from `swift build -c release`, icon via `iconutil`) and **signed with the `jevpaste-dev` identity**
  (see the signing-identity decision); ad-hoc builds are never installed.
- Tests use **Swift Testing via the `swiftlang/swift-testing` package dependency**, linked against the
  CLT's own interop library:
  `swift test -Xlinker -L/Library/Developer/CommandLineTools/Library/Developer/usr/lib -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib`.
  Verified on 2026-09-22 (Testing Library 6.3.2): `@Test`/`#expect` run, failures exit non-zero.
- UI is written in code: **AppKit owns windows, panels, the status item and activation/focus behaviour;
  SwiftUI draws the content inside them** through `NSHostingView`. No `.xib`, no asset catalog.

## Consequences

- One build system, one `make check`, fully reproducible offline on this Mac. No Interface Builder,
  no previews — the app is run to be seen.
- The two linker flags are a toolchain-layout workaround; they live in the Makefile in one place. If a
  future CLT release fixes the runtime search path they can be removed; if it changes the path, that
  is the one line to update.
- Should Xcode ever be installed, the package can be opened directly; nothing here forbids it, but no
  artefact in the repo may *require* it.
