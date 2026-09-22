#!/bin/bash
# Installs the git pre-commit hook that runs `make check` — the entire local CI (no hosted CI).
# Run once per clone: scripts/install-hooks.sh
#
# The hook lives in the repository's shared hooks directory, so it applies to every worktree. In a
# checkout that predates the scaffold (no Makefile at its root) it says so and lets the commit through.
# Bypassing it with `git commit --no-verify` is reserved for commits that cannot affect the gate.
set -euo pipefail

cd "$(dirname "$0")/.."
hooks_directory=$(git rev-parse --git-path hooks)
mkdir -p "$hooks_directory"
hook_path="$hooks_directory/pre-commit"

cat > "$hook_path" <<'HOOK'
#!/bin/bash
# Installed by scripts/install-hooks.sh: block the commit unless `make check` passes.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if [[ ! -f Makefile ]]; then
    echo "pre-commit: no Makefile in this checkout; make check skipped"
    exit 0
fi
if ! make check; then
    echo "pre-commit: make check failed; commit blocked"
    exit 1
fi
HOOK

chmod +x "$hook_path"
echo "installed: $hook_path"
