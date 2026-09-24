#!/bin/bash
# press.sh <expected-frontmost-bundle> <fixture-file|-> [wait-seconds]
# Puts the fixture on the clipboard (unless "-"), gates on the frontmost app, fires SIGUSR1, reports digests.
# Fails closed: any failing step (copy, digest, gate, kill) aborts before a result line is printed.
set -euo pipefail
V=${ACC_VAULT:-/tmp/jevpaste-acc/clipboard-vault}  # swiftc -O -o "$V" scripts/acceptance/clipboard-vault.swift
expected=$1; fixture=$2; wait=${3:-3}
pids=$(pgrep -f '^/.*/acceptance/build/JevPaste.app/Contents/MacOS/JevPaste' || true)
if [[ -z "$pids" || "$pids" == *$'\n'* ]]; then echo "ABORT test app pids=[$pids]"; exit 1; fi
pid=$pids
if [[ "$fixture" != "-" ]]; then pbcopy < "$fixture"; sleep 0.6; fi
before=$("$V" digest)
front=$(lsappinfo info -only bundleid "$(lsappinfo front)" | sed 's/.*="\(.*\)"/\1/')
if [[ "$front" != "$expected" ]]; then echo "ABORT front=$front expected=$expected"; exit 1; fi
echo "trigger at $(python3 -c 'import datetime;print(datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3])') front=$front"
kill -USR1 "$pid"
sleep "$wait"
after=$("$V" digest)
echo "before: $before"; echo "after:  $after"
if [[ "${before#*sha256=}" == "${after#*sha256=}" ]]; then
    echo "clipboardSameBytes=true"
else
    echo "clipboardSameBytes=false"; exit 1
fi
