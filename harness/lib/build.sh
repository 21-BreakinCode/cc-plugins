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

# ---------------------------------------------------------------------------
# ar_harness_build_eval_loop <name> <description> <scope> <criterion>
# Generates eval/<name>.sh from the eval-loop template.
# ---------------------------------------------------------------------------
ar_harness_build_eval_loop() {
  local name="$1"
  local description="$2"
  local scope="$3"
  local criterion="$4"

  local tmpl_dir
  tmpl_dir=$(ar_harness_templates_dir)
  if [ -z "${tmpl_dir}" ]; then
    ar_log "ERROR: harness templates not found"
    return 1
  fi

  mkdir -p eval
  local out="eval/${name}.sh"

  python3 - "${tmpl_dir}/eval-loop/eval.sh.tmpl" "${out}" \
    "${name}" "${description}" "${scope}" "${criterion}" <<'PYEOF'
import sys
src, dst, name, description, scope, criterion = sys.argv[1:7]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{NAME}}', name)
  .replace('{{DESCRIPTION}}', description)
  .replace('{{SCOPE}}', scope)
  .replace('{{CRITERION}}', criterion))
with open(dst, 'w') as f:
    f.write(content)
PYEOF

  chmod +x "${out}"
  echo "$(pwd)/${out}"
}

# ---------------------------------------------------------------------------
# ar_harness_build_sensor <name> <linter> <rule> <message>
# Generates .claude/sensors/<name>.sh + .claude/sensors/<name>.SENSOR.md.
# ---------------------------------------------------------------------------
ar_harness_build_sensor() {
  local name="$1"
  local linter="$2"
  local rule="$3"
  local message="$4"

  local tmpl_dir
  tmpl_dir=$(ar_harness_templates_dir)
  if [ -z "${tmpl_dir}" ]; then
    ar_log "ERROR: harness templates not found"
    return 1
  fi

  mkdir -p .claude/sensors
  local script_out=".claude/sensors/${name}.sh"
  local doc_out=".claude/sensors/${name}.SENSOR.md"

  python3 - "${tmpl_dir}/sensor/sensor.sh.tmpl" "${script_out}" \
    "${name}" "${linter}" "${rule}" "${message}" <<'PYEOF'
import sys
src, dst, name, linter, rule, message = sys.argv[1:7]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{NAME}}', name)
  .replace('{{LINTER}}', linter)
  .replace('{{RULE}}', rule)
  .replace('{{MESSAGE}}', message))
with open(dst, 'w') as f:
    f.write(content)
PYEOF
  chmod +x "${script_out}"

  python3 - "${tmpl_dir}/sensor/SENSOR.md.tmpl" "${doc_out}" \
    "${name}" "${linter}" "${rule}" "${message}" <<'PYEOF'
import sys
src, dst, name, linter, rule, message = sys.argv[1:7]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{NAME}}', name)
  .replace('{{LINTER}}', linter)
  .replace('{{RULE}}', rule)
  .replace('{{MESSAGE}}', message))
with open(dst, 'w') as f:
    f.write(content)
PYEOF

  echo "$(pwd)/${script_out}"
  echo "$(pwd)/${doc_out}"
}
