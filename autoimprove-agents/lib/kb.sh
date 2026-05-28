#!/usr/bin/env bash
# Knowledge base operations (local file store)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Path for a project's entries
aa_kb_project_dir() {
  local project="${1:-$(aa_project_name)}"
  echo "${AA_DATA_DIR}/${project}/entries"
}

# Write a new KB entry
# Usage: aa_kb_write <project> <title> <content> <tags> <status>
aa_kb_write() {
  local project="$1"
  local title="$2"
  local content="$3"
  local tags="${4:-}"
  local status="${5:-active}"
  local date
  date="$(aa_date)"
  local slug
  slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"
  local entry_dir
  entry_dir="$(aa_kb_project_dir "$project")"
  mkdir -p "$entry_dir"
  local filepath="${entry_dir}/${date}-${slug}.md"

  cat > "$filepath" <<EOF
---
title: ${title}
date: ${date}
status: ${status}
tags: [${tags}]
project: ${project}
---

${content}
EOF

  aa_log "KB entry written: ${filepath}"
  echo "$filepath"
}

# Archive an entry by updating its status field
aa_kb_archive() {
  local filepath="$1"
  if [ ! -f "$filepath" ]; then
    aa_log "ERROR: entry not found: $filepath"
    return 1
  fi
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' 's/^status: active$/status: archived/' "$filepath"
  else
    sed -i 's/^status: active$/status: archived/' "$filepath"
  fi
  aa_log "Archived: $filepath"
}

# List active entries for a project
aa_kb_list_active() {
  local project="${1:-$(aa_project_name)}"
  local entry_dir
  entry_dir="$(aa_kb_project_dir "$project")"
  [ -d "$entry_dir" ] || return 0
  grep -l "^status: active$" "${entry_dir}"/*.md 2>/dev/null || true
}

# Search entries by tag
aa_kb_search_tag() {
  local project="${1:-$(aa_project_name)}"
  local tag="$2"
  local entry_dir
  entry_dir="$(aa_kb_project_dir "$project")"
  [ -d "$entry_dir" ] || return 0
  grep -l "\\b${tag}\\b" "${entry_dir}"/*.md 2>/dev/null || true
}
