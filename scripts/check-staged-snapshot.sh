#!/bin/bash
# The pre-commit gate: runs `make check` on exactly what is staged, not on the working tree, so unstaged edits
# and untracked files can neither pass nor fail a commit. Mechanism: docs/quality-gate.md ("Staged snapshot").
#
# The staged files are exported with `git checkout-index` and synchronised by content (rsync --checksum, no
# times) into a persistent snapshot directory inside this worktree's git directory. Unchanged files keep their
# mtimes and the snapshot keeps its own .build/ and a node_modules link, so builds there stay incremental.
#
# STAGED_CHECK_COMMAND overrides the command run in the snapshot (default `make check`); the hermetic test
# scripts/test-staged-snapshot.sh uses it. Exit codes: that command's exit code; 1 if the export fails.
set -euo pipefail

worktree_root=$(git rev-parse --show-toplevel)
snapshot_directory="$(git rev-parse --absolute-git-dir)/staged-snapshot"
check_command=${STAGED_CHECK_COMMAND:-make check}

export_directory=$(mktemp -d)
trap 'rm -rf "$export_directory"' EXIT
# Honours GIT_INDEX_FILE, which `git commit -a` and `git commit <paths>` point at a temporary index.
git checkout-index --all --prefix="$export_directory/"

mkdir -p "$snapshot_directory"
# Excluded paths are never deleted by --delete: the snapshot's build products and dependency links survive.
rsync --recursive --links --perms --checksum --delete \
    --exclude=/.build/ --exclude=/build/ --exclude=/node_modules \
    "$export_directory/" "$snapshot_directory/"
if [[ -d "$worktree_root/node_modules" && ! -e "$snapshot_directory/node_modules" ]]; then
    ln -s "$worktree_root/node_modules" "$snapshot_directory/node_modules"
fi

echo "pre-commit: checking the staged snapshot in $snapshot_directory"
cd "$snapshot_directory"
# Git exports GIT_DIR/GIT_INDEX_FILE/GIT_WORK_TREE to hooks; SwiftPM's own git calls inside .build/checkouts
# would then act on this repository. Run the check with a clean git environment.
env -u GIT_DIR -u GIT_INDEX_FILE -u GIT_WORK_TREE bash -c "$check_command"
