#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

sl_ensure_sessions_dir

EDIT_COUNTER="${SESSIONS_DIR}/.edit-counter-${SL_SESSION_SHORT}"
REMINDED_FLAG="${SESSIONS_DIR}/.reminded-${SL_SESSION_SHORT}"

# Read stdin to get hook input (Stop hook provides JSON)
INPUT="$(cat)"

# Check if we already reminded this session
if [ -f "$REMINDED_FLAG" ]; then
  exit 0
fi

# Count edit/write operations
EDIT_COUNT=0
if [ -f "$EDIT_COUNTER" ]; then
  STORED="$(cat "$EDIT_COUNTER" 2>/dev/null)"
  [[ "$STORED" =~ ^[0-9]+$ ]] && EDIT_COUNT="$STORED"
fi

# Quick check: if session file exists and has file entries
LATEST="$(sl_find_latest_session)"
if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  FILE_COUNT="$(grep -c '^- ' "$LATEST" 2>/dev/null || echo 0)"
  [ "$FILE_COUNT" -gt "$EDIT_COUNT" ] && EDIT_COUNT="$FILE_COUNT"
fi

if [ "$EDIT_COUNT" -ge 5 ]; then
  sl_log "Implementation work detected. Run /session-learner:take-away to capture learnings."
  touch "$REMINDED_FLAG"
fi

exit 0
