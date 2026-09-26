#!/bin/bash
# sig.sh <expected-frontmost-bundle> <USR1|USR2>: signals the cursor probe only, only when the expected app is frontmost.
set -euo pipefail
expected=$1; sig=$2
probe=$(pgrep -f '/cursor-context/build/JevPaste.app/Contents/MacOS/JevPaste --cursor-probe' || true)
prod=$(pgrep -f '^/Users/danielmulec/Applications/JevPaste.app/Contents/MacOS/JevPaste' || true)
if [[ -z "$probe" || "$probe" == *$'\n'* || "$probe" == "$prod" ]]; then echo "ABORT probe=[$probe] prod=[$prod]"; exit 1; fi
front=$(lsappinfo info -only bundleid "$(lsappinfo front)" | sed 's/.*="\(.*\)"/\1/')
if [[ "$front" != "$expected" ]]; then echo "ABORT front=$front expected=$expected"; exit 1; fi
echo "signal $sig to probe pid=$probe (production pid=$prod) front=$front at $(date +%H:%M:%S)"
kill -"$sig" "$probe"
