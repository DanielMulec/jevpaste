#!/bin/bash
# live.sh <expected-frontmost-bundle> <fixture-text|-> [wait]: fixture on the clipboard (unless "-"), gate on the
# frontmost app, SIGUSR1 to the instrumented app only (never production), print clipboard digests (never contents).
set -euo pipefail
V=/tmp/jevpaste-acc/clipboard-vault; expected=$1; fixture=$2; wait=${3:-2}
pid=$(pgrep -f '/cursor-context/build/JevPaste.app/Contents/MacOS/JevPaste --accept-signal-trigger' || true)
prod=$(pgrep -f '^/Users/danielmulec/Applications/JevPaste.app' || true)
if [[ -z "$pid" || "$pid" == *$'\n'* || "$pid" == "$prod" ]]; then echo "ABORT app=[$pid] prod=[$prod]"; exit 1; fi
if [[ "$fixture" != "-" ]]; then printf '%s' "$fixture" | pbcopy; sleep 0.6; fi
before=$("$V" digest)
front=$(lsappinfo info -only bundleid "$(lsappinfo front)" | sed 's/.*="\(.*\)"/\1/')
if [[ "$front" != "$expected" ]]; then echo "ABORT front=$front expected=$expected"; exit 1; fi
echo "trigger USR1 pid=$pid (production running: [${prod}]) front=$front at $(date +%H:%M:%S)"
kill -USR1 "$pid"; sleep "$wait"
after=$("$V" digest)
[[ "${before#*sha256=}" == "${after#*sha256=}" ]] && echo "clipboardSameBytes=true" || echo "clipboardSameBytes=false"
