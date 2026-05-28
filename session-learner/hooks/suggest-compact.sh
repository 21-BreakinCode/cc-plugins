#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

sl_ensure_sessions_dir

COUNTER_FILE="${SESSIONS_DIR}/.compact-counter-${SL_SESSION_SHORT}"
THRESHOLD="$SL_COMPACT_THRESHOLD"

# Read current count, increment
COUNT=1
if [ -f "$COUNTER_FILE" ]; then
  STORED="$(cat "$COUNTER_FILE" 2>/dev/null)"
  if [[ "$STORED" =~ ^[0-9]+$ ]] && [ "$STORED" -gt 0 ] && [ "$STORED" -le 1000000 ]; then
    COUNT=$((STORED + 1))
  fi
fi

# Write updated count (atomic: write to temp then move)
TMPFILE="${COUNTER_FILE}.tmp.$$"
echo "$COUNT" > "$TMPFILE"
mv "$TMPFILE" "$COUNTER_FILE"

# Suggest compact at threshold
if [ "$COUNT" -eq "$THRESHOLD" ]; then
  sl_log "${THRESHOLD} tool calls reached — consider /compact if transitioning phases"
fi

# Remind every 25 calls after threshold
if [ "$COUNT" -gt "$THRESHOLD" ] && [ $(( (COUNT - THRESHOLD) % 25 )) -eq 0 ]; then
  sl_log "${COUNT} tool calls — good checkpoint for /compact if context is stale"
fi

exit 0
