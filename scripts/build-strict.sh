#!/bin/bash
# Step 1 of `make check`: strict debug build of every target in Package.swift.
#
# SwiftPM's --explicit-target-dependency-import-check applies to every package in the graph, and the
# swift-testing / swift-syntax dependencies violate it themselves. So the check runs as `warn`, and this
# script fails only when the importing target is one of ours (a directory under Sources/ or Tests/).
# Caveat: SwiftPM reports only the first undeclared import per target.
#
# Exit codes: 0 = build succeeded and none of our targets imports an undeclared target;
#             1 = undeclared import in one of our targets; otherwise the exit code of `swift build`.
set -uo pipefail

cd "$(dirname "$0")/.."

build_log=$(mktemp)
trap 'rm -f "$build_log"' EXIT

swift build \
    -Xswiftc -warnings-as-errors \
    -Xswiftc -strict-concurrency=complete \
    -Xswiftc -enable-upcoming-feature -Xswiftc ExistentialAny \
    --explicit-target-dependency-import-check warn 2>&1 | tee "$build_log"
build_status=${PIPESTATUS[0]}
if ((build_status != 0)); then
    exit "$build_status"
fi

our_targets=$(find Sources Tests -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | paste -sd '|' -)
undeclared_imports=$(grep -E "Target ($our_targets) imports another target" "$build_log")
if [[ -n "$undeclared_imports" ]]; then
    echo "error: undeclared target imports in our modules (declare the dependency in Package.swift):"
    echo "$undeclared_imports"
    exit 1
fi
