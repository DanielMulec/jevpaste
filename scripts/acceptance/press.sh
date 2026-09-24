#!/bin/bash
# press.sh <expected-frontmost-bundle> <fixture-file|-> [wait-seconds]
# Puts the fixture on the clipboard (unless "-"), gates on the frontmost app, fires SIGUSR1, reports digests.
set -u
V=${ACC_VAULT:-/tmp/jevpaste-acc/clipboard-vault}  # swiftc -O -o "$V" scripts/acceptance/clipboard-vault.swift
expected=$1; fixture=$2; wait=${3:-3}
pid=$(pgrep -f 'acceptance/build/JevPaste.app/Contents/MacOS/JevPaste') || { echo "ABORT no test app"; exit 1; }
if [[ "$fixture" != "-" ]]; then pbcopy < "$fixture"; sleep 0.6; fi
before=$($V digest)
front=$(lsappinfo info -only bundleid "$(lsappinfo front)" | sed 's/.*="\(.*\)"/\1/')
if [[ "$front" != "$expected" ]]; then echo "ABORT front=$front expected=$expected"; exit 1; fi
echo "trigger at $(python3 -c 'import datetime;print(datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3])') front=$front"
kill -USR1 "$pid"
sleep "$wait"
after=$($V digest)
echo "before: $before"; echo "after:  $after"
[[ "${before#*sha256=}" == "${after#*sha256=}" ]] && echo "clipboardSameBytes=true" || echo "clipboardSameBytes=false"
