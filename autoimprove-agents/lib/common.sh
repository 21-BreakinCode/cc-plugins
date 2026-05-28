#!/usr/bin/env bash
# Shared utilities for autoimprove-agents

# Dirs
AA_DATA_DIR="${HOME}/.claude/autoimprove-agents"
AA_PROPOSALS_DIR="${AA_DATA_DIR}/proposals"
AA_KB_INDEX="${AA_DATA_DIR}/kb-index.json"

# Config from env vars
AA_AUTO_APPLY_LOW_RISK="${AUTOIMPROVE_AUTO_APPLY_LOW_RISK:-true}"
AA_NOTEBOOKLM_ENABLED="${AUTOIMPROVE_NOTEBOOKLM_ENABLED:-false}"

# Logging
aa_log() { echo "[autoimprove-agents] $*" >&2; }

# Ensure data dirs exist
aa_ensure_dirs() {
  mkdir -p "$AA_DATA_DIR" "$AA_PROPOSALS_DIR"
}

# Check if jq is available
aa_has_jq() { command -v jq >/dev/null 2>&1; }

# Check if notebooklm-py is available
aa_has_notebooklm() { command -v notebooklm >/dev/null 2>&1 || python3 -c "import notebooklm" >/dev/null 2>&1; }

# Get current project name (basename of cwd or git root)
aa_project_name() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    basename "$(git rev-parse --show-toplevel)"
  else
    basename "$PWD"
  fi
}

# Date helpers
aa_date() { date +%Y-%m-%d; }
aa_datetime() { date "+%Y-%m-%d %H:%M:%S"; }
