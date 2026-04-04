#!/usr/bin/env bash
# Shared utilities for autoresearch plugin

set -euo pipefail

# Directories
AR_AUTORESEARCH_DIR=".autoresearch"
AR_EXPERIMENTS_FILE="${AR_AUTORESEARCH_DIR}/experiments.json"
AR_DASHBOARD_FILE="${AR_AUTORESEARCH_DIR}/dashboard.html"
AR_PROGRAM_FILE="${AR_AUTORESEARCH_DIR}/program.md"

# Plugin root (where templates live)
AR_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AR_TEMPLATES_DIR="${AR_PLUGIN_DIR}/templates"

# Logging
ar_log() {
  echo "[autoresearch] $*" >&2
}

# Date/time helpers
ar_date() {
  date -u +"%Y-%m-%d"
}

ar_datetime() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Ensure .autoresearch directory exists
ar_ensure_dir() {
  mkdir -p "${AR_AUTORESEARCH_DIR}"
}

# Add .autoresearch/ to .gitignore if not already present
ar_ensure_gitignore() {
  local gitignore=".gitignore"
  if [ -f "${gitignore}" ]; then
    if ! grep -q "^\.autoresearch/" "${gitignore}" 2>/dev/null; then
      echo ".autoresearch/" >> "${gitignore}"
      ar_log "Added .autoresearch/ to .gitignore"
    fi
  else
    echo ".autoresearch/" > "${gitignore}"
    ar_log "Created .gitignore with .autoresearch/"
  fi
}

# Check if jq is available
ar_has_jq() {
  command -v jq &>/dev/null
}

# Escape string for JSON embedding (handles quotes, newlines, backslashes)
ar_escape_json() {
  local input="$1"
  printf '%s' "${input}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
}
