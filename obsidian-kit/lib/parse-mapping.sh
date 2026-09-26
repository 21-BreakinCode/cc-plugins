#!/usr/bin/env bash
# parse-mapping.sh — parse the "## Service Mapping" markdown table from an
# initiation.md file. Emits one pipe-separated record per data row to stdout:
#   <app_name>|<repo_path>|<lifeos_subpath>
# Whitespace is trimmed. $HOME and $LifeOS are NOT expanded — caller does that.
# Exit 0 even when table is empty or missing (caller handles).

set -euo pipefail

init_file="${1:?usage: parse-mapping.sh <path-to-initiation.md>}"

if [ ! -f "$init_file" ]; then
    echo "parse-mapping.sh: file not found: $init_file" >&2
    exit 2
fi

awk '
BEGIN { in_section=0; saw_header=0; saw_sep=0 }
/^## Service Mapping[[:space:]]*$/ { in_section=1; next }
/^## / && in_section { exit }
in_section && /^$/ && saw_sep { exit }
in_section && /^\|/ {
    if (!saw_header) { saw_header=1; next }
    if (!saw_sep)    { saw_sep=1;    next }
    n = split($0, cols, /[[:space:]]*\|[[:space:]]*/)
    out = ""
    for (i=2; i<n; i++) {
        if (out != "") out = out "|"
        out = out cols[i]
    }
    if (out != "") print out
}
' "$init_file"
