#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/template.sh"

# Validate config
zc_check_config || exit 0  # exit 0 = soft fail (don't block session end)

# Ensure inbox folder exists
INBOX="$(zc_inbox_path)"
mkdir -p "$INBOX"

# Find today's session file from session-learner
SESSION_FILE="$(zc_find_session_file)"
if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then
  zc_log "No session file found for today. Skipping."
  exit 0
fi

SESSION_CONTENT="$(cat "$SESSION_FILE")"

# Extract title from session file (first H1 or date-based fallback)
TITLE="$(grep -m1 '^# ' "$SESSION_FILE" | sed 's/^# //' || echo "Session $(date +%Y-%m-%d)")"

# Extract tasks section for insights
INSIGHTS="$(awk '/^## Tasks/,/^## /' "$SESSION_FILE" | grep '^- ' | head -8 || echo "- See session file")"

# Build tags from files modified section
TAGS=""
if grep -q "^## Files Modified" "$SESSION_FILE"; then
  TAGS="$(grep -A20 "^## Files Modified" "$SESSION_FILE" | grep '^- ' | \
    sed 's|.*/||' | sed 's/\.[^.]*$//' | head -5 | paste -sd',' - | tr -d ' ')"
fi

# Check if a diagram stub is needed
EXCALIDRAW_NAME=""
if zc_needs_diagram "$SESSION_CONTENT"; then
  SLUG="$(zc_slugify "$TITLE")"
  EXCALIDRAW_NAME="$SLUG"
  EXCALIDRAW_PATH="${INBOX}/${SLUG}.excalidraw"
  zc_generate_excalidraw_stub > "$EXCALIDRAW_PATH"
  zc_log "Created excalidraw stub: ${EXCALIDRAW_PATH}"
fi

# Generate and write the draft note
SLUG="$(zc_slugify "$TITLE")"
NOTE_PATH="${INBOX}/$(date +%Y-%m-%d)-${SLUG}.md"

zc_generate_note \
  "$TITLE" \
  "Session on $(date +%Y-%m-%d). Review and expand below." \
  "$INSIGHTS" \
  "draft,$(date +%Y-%m)" \
  "$EXCALIDRAW_NAME" \
  > "$NOTE_PATH"

zc_log "Draft note created: ${NOTE_PATH}"
exit 0
