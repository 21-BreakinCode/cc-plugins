#!/usr/bin/env bash
# Dashboard generator for autoresearch

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Generate dashboard.html from experiments.json and template
# Returns: 0 on success, 1 on failure
ar_dashboard_generate() {
  local template="${AR_TEMPLATES_DIR}/dashboard.html"
  local data_file="${AR_EXPERIMENTS_FILE}"
  local output="${AR_DASHBOARD_FILE}"

  if [ ! -f "${template}" ]; then
    ar_log "ERROR: Dashboard template not found at ${template}"
    return 1
  fi

  if [ ! -f "${data_file}" ]; then
    ar_log "ERROR: experiments.json not found at ${data_file}"
    return 1
  fi

  python3 -c "
import sys
with open('${template}', 'r') as f:
    html = f.read()
with open('${data_file}', 'r') as f:
    data = f.read()
result = html.replace('{{DATA_JSON}}', data)
with open('${output}', 'w') as f:
    f.write(result)
"

  if [ $? -ne 0 ]; then
    ar_log "ERROR: Failed to generate dashboard"
    return 1
  fi

  ar_log "Dashboard updated: ${output}"
  return 0
}

# Open dashboard in the default browser (macOS)
# Returns: 0 on success (or best-effort warning), never blocks the loop
ar_dashboard_open() {
  local dashboard="${AR_DASHBOARD_FILE}"

  if [ ! -f "${dashboard}" ]; then
    ar_log "WARNING: Dashboard file not found at ${dashboard}"
    return 0
  fi

  if command -v open &>/dev/null; then
    open "${dashboard}" 2>/dev/null || ar_log "WARNING: Could not open dashboard. Open manually: ${dashboard}"
  else
    ar_log "Dashboard ready at: ${dashboard}"
  fi

  return 0
}
