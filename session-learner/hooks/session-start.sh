#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Warn if jq not installed
if ! sl_has_jq; then
  sl_log "WARNING: jq is not installed. Session summaries will not be saved."
  sl_log "Install with: brew install jq (macOS) or sudo apt install jq (Linux)"
fi

# Find latest session file
LATEST="$(sl_find_latest_session)"

if [ -z "$LATEST" ] || [ ! -f "$LATEST" ]; then
  exit 0
fi

SESSION_CONTENT="$(cat "$LATEST")"

# Extract stored git HEAD from session file (macOS-compatible, no grep -P)
STORED_HEAD="$(grep 'Git HEAD:' "$LATEST" 2>/dev/null | sed 's/.*\*\*Git HEAD:\*\* //' || true)"

# Build context to inject
CONTEXT="$SESSION_CONTENT"

# Git-aware check: compare stored HEAD with current
if sl_in_git_repo && [ -n "$STORED_HEAD" ]; then
  CURRENT_HEAD="$(sl_git_head)"

  if [ "$STORED_HEAD" != "$CURRENT_HEAD" ]; then
    COMMIT_COUNT="$(git rev-list --count "${STORED_HEAD}..${CURRENT_HEAD}" 2>/dev/null || echo "unknown")"

    if [ "$SL_GIT_MODE" = "full" ]; then
      GIT_LOG="$(git log --oneline "${STORED_HEAD}..${CURRENT_HEAD}" 2>/dev/null | head -20)"
      GIT_STAT="$(git diff --stat "${STORED_HEAD}..${CURRENT_HEAD}" 2>/dev/null | tail -20)"

      CONTEXT="${CONTEXT}

---
Warning: Codebase changed since this session (${COMMIT_COUNT} commits):

${GIT_LOG}

Changed files:
${GIT_STAT}

File references in the previous summary may be stale."
    else
      CONTEXT="${CONTEXT}

---
Warning: Codebase changed: ${COMMIT_COUNT} commits since this summary. File references may be stale."
    fi
  fi
fi

# Output JSON for context injection via stdout
ESCAPED="$(sl_escape_json "$CONTEXT")"

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${ESCAPED}"
  }
}
EOF

exit 0
