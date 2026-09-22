#!/bin/bash
# Line-count guard for non-Swift text files (scripts, Makefile, YAML, JSON, Markdown, configs).
# Swift files are held to the same ceiling by SwiftLint's file_length rule.
#
# Counts physical lines the way SwiftLint does: a final line without a trailing newline still counts
# (awk's NR includes it; `wc -l` would not). Binary files are skipped.
# Exit codes: 0 = every file within the ceiling, 1 = at least one file over it.
set -euo pipefail

cd "$(dirname "$0")/.."
MAXIMUM_LINES=400
EXCLUDED_PATHS='^(frames/|spikes/|node_modules/|\.build/|build/|video\.mp4$)'

over_ceiling=0
while IFS= read -r path; do
    [[ -f "$path" ]] || continue
    [[ "$path" == *.swift ]] && continue
    grep -Iq . "$path" || continue
    line_count=$(awk 'END { print NR }' "$path")
    if ((line_count > MAXIMUM_LINES)); then
        echo "$path:$line_count: error: $line_count lines exceed the $MAXIMUM_LINES-line ceiling"
        over_ceiling=1
    fi
done < <(git ls-files --cached --others --exclude-standard | grep -Ev "$EXCLUDED_PATHS")

exit "$over_ceiling"
