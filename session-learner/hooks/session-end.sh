#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

sl_ensure_sessions_dir

# Read stdin JSON (Claude provides session_id, transcript_path, cwd)
INPUT="$(cat)"

TODAY="$(sl_date)"
NOW="$(sl_time)"
SESSION_FILE="${SESSIONS_DIR}/${TODAY}-${SL_SESSION_SHORT}.md"

# Try to get transcript path from stdin JSON
TRANSCRIPT_PATH=""
if sl_has_jq; then
  TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
fi

# Get git info (if in a repo)
GIT_BRANCH=""
GIT_HEAD=""
if sl_in_git_repo; then
  GIT_BRANCH="$(sl_git_branch)"
  GIT_HEAD="$(sl_git_head)"
fi

# If session file already exists, just update timestamp and exit
if [ -f "$SESSION_FILE" ]; then
  # Update Last Updated timestamp using sed (portable macOS/Linux)
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s/^\*\*Last Updated:\*\*.*/\*\*Last Updated:\*\* ${NOW}/" "$SESSION_FILE"
  else
    sed -i "s/^\*\*Last Updated:\*\*.*/\*\*Last Updated:\*\* ${NOW}/" "$SESSION_FILE"
  fi
  exit 0
fi

# Parse transcript if jq available and transcript exists
TASKS=""
FILES_MODIFIED=""
TOOLS_USED=""
MSG_COUNT=0

if sl_has_jq && [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Extract user messages (last 10, truncated to 200 chars)
  TASKS="$(jq -r '
    select(
      .type == "user" or .role == "user" or .message?.role == "user"
    )
    | (.message?.content // .content)
    | if type == "array" then map(.text // "") | join(" ") else . end
    | tostring
    | .[0:200]
    | gsub("\n"; " ")
  ' "$TRANSCRIPT_PATH" 2>/dev/null | tail -10)"

  MSG_COUNT="$(echo "$TASKS" | grep -c . 2>/dev/null || echo 0)"

  # Extract files modified (Edit/Write tool uses)
  FILES_MODIFIED="$(jq -r '
    if .type == "tool_use" or .tool_name != null then
      if (.tool_name // .name) == "Edit" or (.tool_name // .name) == "Write" then
        (.tool_input?.file_path // .input?.file_path // empty)
      else empty end
    elif .type == "assistant" and (.message?.content | type) == "array" then
      .message.content[]
      | select(.type == "tool_use")
      | select(.name == "Edit" or .name == "Write")
      | .input?.file_path // empty
    else empty end
  ' "$TRANSCRIPT_PATH" 2>/dev/null | sort -u)"

  # Extract tool names
  TOOLS_USED="$(jq -r '
    if .type == "tool_use" or .tool_name != null then
      (.tool_name // .name // empty)
    elif .type == "assistant" and (.message?.content | type) == "array" then
      .message.content[] | select(.type == "tool_use") | .name // empty
    else empty end
  ' "$TRANSCRIPT_PATH" 2>/dev/null | sort -u | head -20 | paste -sd', ' -)"
fi

# Build session file
{
  echo "# Session: ${TODAY}"
  echo "**Started:** ${NOW}"
  echo "**Last Updated:** ${NOW}"
  [ -n "$GIT_BRANCH" ] && echo "**Git Branch:** ${GIT_BRANCH}"
  [ -n "$GIT_HEAD" ] && echo "**Git HEAD:** ${GIT_HEAD}"
  echo ""

  if [ -n "$TASKS" ]; then
    echo "## Tasks"
    echo "$TASKS" | while IFS= read -r line; do
      [ -n "$line" ] && echo "- ${line}"
    done
    echo ""
  fi

  if [ -n "$FILES_MODIFIED" ]; then
    echo "## Files Modified"
    echo "$FILES_MODIFIED" | while IFS= read -r line; do
      [ -n "$line" ] && echo "- ${line}"
    done
    echo ""
  fi

  if [ -n "$TOOLS_USED" ]; then
    echo "## Tools Used"
    echo "$TOOLS_USED"
    echo ""
  fi

  echo "## Stats"
  echo "- User messages: ${MSG_COUNT}"

} > "$SESSION_FILE"

# Fallback: if no jq, save minimal session file
if ! sl_has_jq; then
  {
    echo "# Session: ${TODAY}"
    echo "**Started:** ${NOW}"
    echo "**Last Updated:** ${NOW}"
    [ -n "$GIT_BRANCH" ] && echo "**Git Branch:** ${GIT_BRANCH}"
    [ -n "$GIT_HEAD" ] && echo "**Git HEAD:** ${GIT_HEAD}"
    echo ""
    echo "## Note"
    echo "Install jq for full transcript parsing: brew install jq (macOS) or sudo apt install jq (Linux)"
  } > "$SESSION_FILE"
fi

exit 0
