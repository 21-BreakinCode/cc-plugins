#!/usr/bin/env bash
# resolve-service.sh — given a cwd and an org, look up the app_name and
# lifeos_subpath from the org's Service Mapping table.
#
# Usage: resolve-service.sh <cwd> <org>
# Output: <app_name>|<lifeos_subpath> on stdout when matched.
# Exit codes:
#   0 — match found
#   1 — no match (caller asks the user)
#   2 — initiation.md missing for org
#   3 — LifeOS unreachable
#
# Optional env var: HH_LIFEOS_ROOT overrides the LifeOS path (for tests).

set -euo pipefail

cwd="${1:?usage: resolve-service.sh <cwd> <org>}"
org="${2:?usage: resolve-service.sh <cwd> <org>}"

LIFEOS="${HH_LIFEOS_ROOT:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS}"
PROJECT_ROOT="$LIFEOS/01Project"

if [ ! -d "$PROJECT_ROOT" ]; then
    echo "resolve-service.sh: LifeOS not reachable at $PROJECT_ROOT" >&2
    exit 3
fi

init="$PROJECT_ROOT/$org/handover_handler__initiation.md"
if [ ! -f "$init" ]; then
    echo "resolve-service.sh: initiation file missing: $init" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
records="$(bash "$SCRIPT_DIR/parse-mapping.sh" "$init")"
[ -n "$records" ] || exit 1

best_match=""
best_match_len=0

while IFS='|' read -r app_name repo_path lifeos_subpath; do
    [ -n "$app_name" ] || continue
    expanded="${repo_path//\$HOME/$HOME}"
    expanded="${expanded//\$LifeOS/$LIFEOS}"

    if [ "$cwd" = "$expanded" ]; then
        echo "$app_name|$lifeos_subpath"
        exit 0
    fi
    if [[ "$cwd" == "$expanded"/* ]]; then
        len=${#expanded}
        if [ "$len" -gt "$best_match_len" ]; then
            best_match="$app_name|$lifeos_subpath"
            best_match_len=$len
        fi
    fi
done <<< "$records"

if [ -n "$best_match" ]; then
    echo "$best_match"
    exit 0
fi
exit 1
