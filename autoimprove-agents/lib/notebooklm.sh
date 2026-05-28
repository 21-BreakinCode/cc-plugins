#!/usr/bin/env bash
# NotebookLM integration wrapper using notebooklm-py
# Requires: pip install notebooklm-py, AUTOIMPROVE_GOOGLE_ACCOUNT set

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Check prerequisites
aa_nlm_check() {
  if ! aa_has_notebooklm; then
    aa_log "ERROR: notebooklm-py not installed. Run: pip install notebooklm-py"
    return 1
  fi
  if [ -z "${AUTOIMPROVE_GOOGLE_ACCOUNT:-}" ]; then
    aa_log "ERROR: AUTOIMPROVE_GOOGLE_ACCOUNT not set in config.sh"
    return 1
  fi
  return 0
}

# Push a local KB entry file to a NotebookLM notebook
# Usage: aa_nlm_push_entry <notebook-name> <entry-filepath>
aa_nlm_push_entry() {
  local notebook="$1"
  local filepath="$2"
  aa_nlm_check || return 1
  python3 -c "
import notebooklm, sys
nb = notebooklm.get_or_create_notebook('${notebook}')
nb.add_source('${filepath}')
print('Pushed to notebook: ${notebook}')
"
}

# Archive a source in NotebookLM by title
aa_nlm_archive_entry() {
  local notebook="$1"
  local title="$2"
  aa_nlm_check || return 1
  python3 -c "
import notebooklm
nb = notebooklm.get_notebook('${notebook}')
sources = [s for s in nb.sources if '${title}' in s.title]
for s in sources:
    s.delete()
print('Archived from notebook: ${title}')
"
}

# Query a notebook
aa_nlm_query() {
  local notebook="$1"
  local question="$2"
  aa_nlm_check || return 1
  python3 -c "
import notebooklm
nb = notebooklm.get_notebook('${notebook}')
result = nb.chat('${question}')
print(result)
"
}
