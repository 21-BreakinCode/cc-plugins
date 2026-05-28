#!/usr/bin/env bash
# Shared utilities for zettelkasten-capture

# Load user config
ZC_CONFIG="${HOME}/.claude/zettelkasten-capture/config.sh"
[ -f "$ZC_CONFIG" ] && source "$ZC_CONFIG"

# Required config (must be set by user)
ZC_OBSIDIAN_VAULT="${ZC_OBSIDIAN_VAULT:-}"
ZC_INBOX_FOLDER="${ZC_INBOX_FOLDER:-Inbox}"

# Optional config
ZC_EXCALIDRAW_THRESHOLD="${ZC_EXCALIDRAW_THRESHOLD:-1}"
ZC_AUTO_PUSH_TO_KB="${ZC_AUTO_PUSH_TO_KB:-false}"
ZC_SESSIONS_DIR="${ZC_SESSIONS_DIR:-${HOME}/.claude/sessions}"

# Logging
zc_log() { echo "[zettelkasten-capture] $*" >&2; }

# Validate required config
zc_check_config() {
  if [ -z "$ZC_OBSIDIAN_VAULT" ]; then
    zc_log "ERROR: ZC_OBSIDIAN_VAULT not set. Copy config/config.example.sh to ~/.claude/zettelkasten-capture/config.sh"
    return 1
  fi
  if [ ! -d "$ZC_OBSIDIAN_VAULT" ]; then
    zc_log "ERROR: Obsidian vault not found at: $ZC_OBSIDIAN_VAULT"
    return 1
  fi
  return 0
}

# Full path to inbox folder
zc_inbox_path() {
  echo "${ZC_OBSIDIAN_VAULT}/${ZC_INBOX_FOLDER}"
}

# Find today's session-learner file
zc_find_session_file() {
  local today
  today="$(date +%Y-%m-%d)"
  find "$ZC_SESSIONS_DIR" -name "${today}-*.md" -type f 2>/dev/null | sort -r | head -1
}

# Slugify a title for filenames
zc_slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-'
}

# Check if session content suggests a diagram is needed
zc_needs_diagram() {
  local content="$1"
  echo "$content" | grep -iqE "architect|diagram|flow|system|design|component|pipeline|sequence|struct" && return 0 || return 1
}
