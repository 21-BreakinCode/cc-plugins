#!/usr/bin/env bash
# Shared utilities for session-learner hooks

SESSIONS_DIR="${HOME}/.claude/sessions"

# Config from env vars with defaults
SL_GIT_MODE="${CLAUDE_SESSION_LEARNER_GIT_MODE:-full}"
SL_COMPACT_THRESHOLD="${CLAUDE_SESSION_LEARNER_COMPACT_THRESHOLD:-50}"
SL_MAX_AGE_DAYS="${CLAUDE_SESSION_LEARNER_MAX_AGE_DAYS:-7}"

# Session ID (last 8 chars of CLAUDE_SESSION_ID, fallback "default")
SL_SESSION_SHORT="${CLAUDE_SESSION_ID:-default}"
SL_SESSION_SHORT="${SL_SESSION_SHORT:(-8)}"

# Date/time helpers
sl_date() { date +%Y-%m-%d; }
sl_time() { date +%H:%M; }
sl_datetime() { date "+%Y-%m-%d %H:%M:%S"; }

# Logging (stderr = visible to user as hook output)
sl_log() { echo "[session-learner] $*" >&2; }

# Ensure sessions directory exists
sl_ensure_sessions_dir() {
  mkdir -p "$SESSIONS_DIR"
}

# Check if jq is available
sl_has_jq() {
  command -v jq >/dev/null 2>&1
}

# Escape a string for embedding in JSON value (no jq needed)
sl_escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Find latest session file within max age
# Outputs the path to the most recent session file, or empty string
sl_find_latest_session() {
  sl_ensure_sessions_dir
  local max_age_days="${1:-$SL_MAX_AGE_DAYS}"
  find "$SESSIONS_DIR" -name '????-??-??-????????.md' -mtime "-${max_age_days}" -type f 2>/dev/null \
    | sort -r \
    | head -1
}

# Check if we're in a git repo
sl_in_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Get current git HEAD short SHA (8 chars)
sl_git_head() {
  git rev-parse --short=8 HEAD 2>/dev/null || echo ""
}

# Get current git branch
sl_git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}
