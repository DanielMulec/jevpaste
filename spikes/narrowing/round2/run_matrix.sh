#!/bin/bash
# Matrix: every round-1 cell and every held-out cell, 2 runs, design r2 (frozen at GATE A). Resumable.
cd "$(dirname "$0")"
set -a; . ~/.config/jevpaste/env; set +a
for RUN in 0 1; do
  python3 r2.py run matrix r2 $RUN matrix whole chooser new heldout || exit $?
done
echo MATRIX DONE
