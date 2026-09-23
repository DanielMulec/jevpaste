# jevpaste developer entry points. `make check` is the entire local CI (no hosted CI):
# offline, fail-fast, in the order decided in "Choose native module boundaries and local quality checks".
# Exit-code contract of every step: docs/quality-gate.md.

.PHONY: check build-strict format-lint lint duplication test dead-code line-counts hook-test \
	format acceptance app install

# Swift Testing ships in the Command Line Tools, but its interop library is not on the default search
# path (ADR 0001). The one place these linker flags live besides .periphery.yml.
CLT_LIBRARY_PATH := /Library/Developer/CommandLineTools/Library/Developer/usr/lib
TESTING_LINKER_FLAGS := -Xlinker -L$(CLT_LIBRARY_PATH) -Xlinker -rpath -Xlinker $(CLT_LIBRARY_PATH)

# SwiftLint looks for SourceKit in an Xcode toolchain and aborts without one; pointing it at the CLT
# toolchain loads the CLT's sourcekitdInProc, which the custom rules need (see docs/quality-gate.md).
SWIFTLINT_TOOLCHAIN := /Library/Developer/CommandLineTools

INSTALLED_APP := $(HOME)/Applications/JevPaste.app
BUILT_APP := build/JevPaste.app

check: build-strict format-lint lint duplication test dead-code line-counts hook-test
	@echo "make check: all steps passed"

build-strict:
	scripts/build-strict.sh

format-lint:
	swift format lint --strict -r Sources Tests

lint:
	TOOLCHAIN_DIR=$(SWIFTLINT_TOOLCHAIN) swiftlint lint --strict --quiet --no-cache

duplication:
	npx --no-install jscpd --config .jscpd.json

test:
	swift test $(TESTING_LINKER_FLAGS)

dead-code:
	periphery scan

line-counts:
	scripts/check-line-counts.sh

# Hermetic: a scratch repository and a stub check command, never a nested `make check`.
hook-test:
	scripts/test-staged-snapshot.sh

format:
	swift format format --in-place -r Sources Tests

acceptance:
	@echo "make acceptance: not implemented yet. It will run the real-app acceptance suite against"
	@echo "$(INSTALLED_APP) (installed, signed with jevpaste-dev, Accessibility granted, Daniel present)."
	@echo "It is never part of make check."

app:
	scripts/make-app.sh

install: app
	rm -rf "$(INSTALLED_APP)"
	mkdir -p "$(HOME)/Applications"
	cp -R "$(BUILT_APP)" "$(INSTALLED_APP)"
	@echo "installed: $(INSTALLED_APP)"
