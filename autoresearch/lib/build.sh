#!/usr/bin/env bash
# Tier-1 scaffolders for /autoresearch:harness-build.
# Each ar_harness_build_<type> writes one (or two) files into the CWD's .claude/
# (or eval/) and prints the absolute paths of the created files on stdout.

set -euo pipefail

# Resolve the templates dir relative to this lib's own location.
ar_harness_templates_dir() {
  ( cd "$(dirname "${BASH_SOURCE[0]}")/../templates/harness-components" 2>/dev/null && pwd )
}

# Source common helpers (for ar_log).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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

# ---------------------------------------------------------------------------
# ar_harness_build_context_report
# Walks .claude/agents and .claude/skills for agent/skill files exceeding
# 300 lines and writes a Markdown advisory report at
# .claude/harness-report-YYYY-MM-DD.md. Never auto-edits agent files.
# ---------------------------------------------------------------------------
ar_harness_build_context_report() {
  mkdir -p .claude
  local out=".claude/harness-report-$(ar_date).md"

  python3 - "${out}" <<'PYEOF'
import os
import re
import sys

out_path = sys.argv[1]
cwd = os.getcwd()
OVERSIZED_LINES = 300

oversized = []
for sub in ('.claude/agents', '.claude/skills'):
    abs_sub = os.path.join(cwd, sub)
    if not os.path.isdir(abs_sub):
        continue
    for dirpath, _, filenames in os.walk(abs_sub):
        for fname in filenames:
            if not fname.endswith('.md'):
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, 'r', errors='ignore') as f:
                    lines = f.readlines()
                if len(lines) > OVERSIZED_LINES:
                    # Heuristic: count top-level (## or #) headings as "responsibilities"
                    headings = [
                        l.strip() for l in lines
                        if re.match(r'^#{1,2}\s+\S', l) and 'frontmatter' not in l.lower()
                    ]
                    oversized.append({
                        'path': os.path.relpath(fpath, cwd),
                        'lines': len(lines),
                        'headings': headings[:8],
                    })
            except Exception:
                pass

with open(out_path, 'w') as f:
    f.write('# Harness Context-Mgmt Report\n\n')
    if not oversized:
        f.write('No agent/skill files exceed 300 lines. Nothing to recommend.\n')
    else:
        f.write(f'{len(oversized)} file(s) exceed 300 lines. Suggested splits below.\n\n')
        for item in oversized:
            f.write(f"## `{item['path']}` ({item['lines']} lines)\n\n")
            if item['headings']:
                f.write('**Top-level sections in this file:**\n\n')
                for h in item['headings']:
                    f.write(f'- {h}\n')
                f.write('\n')
                f.write(
                    '**Suggested split:** group sections that share a noun '
                    '(e.g. all sections about "input" → one file; all about '
                    '"output" → another). Aim for each split to stay below '
                    '300 lines and own one responsibility.\n\n'
                )
            else:
                f.write(
                    '**Suggested split:** no clear section structure found. '
                    'Add `## Section` headings to expose responsibilities, '
                    'then split.\n\n'
                )

print(out_path)
PYEOF
}
