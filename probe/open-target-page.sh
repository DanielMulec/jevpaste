#!/bin/bash
# PROTOTYPE — history-probe, never merged. Opens the target page in Chrome: an "Email address" textarea and a
# non-editable paragraph (refusal step).
open -a "Google Chrome" "$(cd "$(dirname "$0")" && pwd)/target.html"
