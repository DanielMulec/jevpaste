#!/bin/bash
# OLD on the first row, NEAR on the row above the prompt, the prompt on the last row of the pane.
n=$(tput lines); clear; echo "# JEVPASTE-OLD-51"
for ((i = 2; i <= n - 2; i++)); do echo "# filler line $i ........................................"; done
echo "# JEVPASTE-NEAR-51"
