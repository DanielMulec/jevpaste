#!/bin/bash
# Hermetic test of scripts/check-staged-snapshot.sh (step `hook-test` of `make check`): a scratch git repository
# and a stub check command, never the real `make check`. Proves the gate sees the staged snapshot, not the
# working tree, and that the snapshot keeps its build products and unchanged files' mtimes across runs.
# Exit codes: 0 = every case passed, 1 = at least one failed.
set -uo pipefail
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

script_under_test="$(cd "$(dirname "$0")" && pwd)/check-staged-snapshot.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cd "$scratch" || exit 1
git init --quiet
git config user.name "staged snapshot test"
git config user.email "staged-snapshot@example.invalid"
snapshot="$(git rev-parse --absolute-git-dir)/staged-snapshot"

failures=0
# expect <description> <expected: pass|fail> <stub check command>
expect() {
    if STAGED_CHECK_COMMAND="$3" "$script_under_test" >/dev/null 2>&1; then actual=pass; else actual=fail; fi
    if [[ "$actual" == "$2" ]]; then
        echo "ok - $1"
    else
        echo "not ok - $1 (expected $2, got $actual)"
        failures=1
    fi
}

echo good >verdict.txt
echo stable >unchanged.txt
echo tracked >deleted.txt
git add verdict.txt unchanged.txt deleted.txt
git commit --quiet -m "initial"

echo bad >verdict.txt
echo untracked >untracked.txt
expect "a staged good file passes although the working tree is bad" pass "grep -qx good verdict.txt"
expect "an untracked file is not in the snapshot" pass "test ! -e untracked.txt"

echo bad >verdict.txt && git add verdict.txt && echo good >verdict.txt
expect "a staged bad file fails although the working tree is good" fail "grep -qx good verdict.txt"

mkdir -p "$snapshot/.build" && touch "$snapshot/.build/product"
touch -t 202001010000 "$snapshot/unchanged.txt"
git rm --quiet deleted.txt
expect "a staged deletion is gone from the snapshot" pass "test ! -e deleted.txt"
expect "the snapshot keeps its .build products" pass "test -e .build/product"
expect "an unchanged file keeps its mtime" pass "test \$(stat -f %Sm -t %Y unchanged.txt) = 2020"

exit "$failures"
