#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

sl_ensure_sessions_dir

# Remind user to capture insights before compaction
sl_log "Context compaction upcoming. Consider /session-learner:take-away first."

# Annotate active session file with compaction timestamp
LATEST="$(sl_find_latest_session)"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  NOW="$(sl_time)"
  echo "" >> "$LATEST"
  echo "---" >> "$LATEST"
  echo "**[Compaction at ${NOW}]** — Context was summarized" >> "$LATEST"
fi

exit 0
