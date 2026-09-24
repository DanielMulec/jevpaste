#!/bin/bash
# term-press.sh <fixture|-> [wait]: gate on the scratch pane being focused and Ghostty frontmost, then press.
set -euo pipefail
P=${ACC_SCRATCH_PANE:?herdr pane id of the scratch shell}; ME=${ACC_SELF_PANE:?herdr pane id of the driving agent}
open -a Ghostty; sleep 0.5
f=$(herdr pane get $P | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["pane"]["focused"])')
m=$(herdr pane get $ME | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["pane"]["focused"])')
if [[ "$f" != "True" || "$m" != "False" ]]; then echo "ABORT scratch focused=$f self focused=$m"; exit 1; fi
"$(dirname "$0")/press.sh" com.mitchellh.ghostty "$1" "${2:-3}"
