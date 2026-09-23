#!/bin/bash
# PROTOTYPE — history-probe, never merged. Puts the three synthetic rows on the clipboard, oldest first,
# ~1 s apart so the running JevPaste captures each as a copy. THREE ends up Active.
set -euo pipefail
printf 'JEVPASTE-HIST-ONE alpha.one@example.org' | pbcopy; sleep 1
printf 'JEVPASTE-HIST-TWO beta.two@example.net' | pbcopy; sleep 1
printf 'JEVPASTE-HIST-THREE gamma.three@example.com' | pbcopy; sleep 1
echo "rows ONE, TWO, THREE copied (THREE is Active)"
