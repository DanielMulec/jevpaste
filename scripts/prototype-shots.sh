#!/bin/bash
# PROTOTYPE — menu-settings, never merged. Captures one prototype state: shot.sh <out.png> <env assignments…>
# Launches the prototype with the env, waits for the window number it writes, captures that window only.
set -u
out=$1; shift
bin=.build/debug/MenuSettingsPrototype
rm -f /tmp/proto-menu.wid /tmp/proto-settings.wid
env PROTO_BACKDROP=1 "$@" "$bin" >/tmp/proto-shot.log 2>&1 &
pid=$!
kind=menu; case "$*" in *PROTO_OPEN=settings*) kind=settings;; esac
sleep "${SHOT_WAIT:-3}"
wid=$(cat /tmp/proto-$kind.wid 2>/dev/null)
if [ -n "$wid" ]; then screencapture -x -o -l "$wid" "$out" && echo "shot $out (window $wid)"; else echo "no window for $out"; fi
kill $pid 2>/dev/null; wait $pid 2>/dev/null
