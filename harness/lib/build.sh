#!/usr/bin/env bash
# Tier-1 scaffolders for /harness:build.
# Each ar_harness_build_<type> writes one (or two) files into the CWD's .claude/
# (or eval/) and prints the absolute paths of the created files on stdout.

set -euo pipefail

# Resolve harness templates dir regardless of where this is sourced from.
# Uses `find -L` so symlinked plugin installs (common in dev) are followed.
ar_harness_templates_dir() {
  find -L ~/.claude/plugins -path '*/harness/templates/harness-components' -print -quit 2>/dev/null
}

# Source common helpers (for ar_log).
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"

# ---------------------------------------------------------------------------
# ar_harness_build_feedback_loop <name> <event> <matcher> <principle>
# Generates .claude/hooks/<name>.json from the feedback-loop template.
# ---------------------------------------------------------------------------
ar_harness_build_feedback_loop() {
  local name="$1"
  local event="$2"
  local matcher="$3"
  local principle="$4"

  local tmpl_dir
  tmpl_dir=$(ar_harness_templates_dir)
  if [ -z "${tmpl_dir}" ]; then
    ar_log "ERROR: harness templates not found"
    return 1
  fi

  mkdir -p .claude/hooks
  local out=".claude/hooks/${name}.json"

  # Substitute. Use python so we don't have to worry about sed-escaping the principle text.
  python3 - "${tmpl_dir}/feedback-loop/hook.json.tmpl" "${out}" \
    "${event}" "${matcher}" "${principle}" <<'PYEOF'
import sys
src, dst, event, matcher, principle = sys.argv[1:6]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{EVENT}}', event)
  .replace('{{MATCHER}}', matcher)
  .replace('{{PRINCIPLE}}', principle.replace("'", "\\'")))
with open(dst, 'w') as f:
    f.write(content)
PYEOF

  echo "$(pwd)/${out}"
}
