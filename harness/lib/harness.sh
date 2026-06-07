#!/usr/bin/env bash
# Harness management for autoresearch — scoring, ranking, scorecard, program generation

set -euo pipefail

source "$(find -L ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"

# ---------------------------------------------------------------------------
# ar_harness_init <probe_results_json>
# Creates .autoresearch/harness.json from flat probe results JSON.
# Input JSON shape (flat): {"lint": {...}, "tests": {...}, "runtime": {...}, "architecture": {...}}
# ---------------------------------------------------------------------------
ar_harness_init() {
  local probe_results_json="$1"

  ar_ensure_dir
  ar_ensure_gitignore

  local project_name
  project_name=$(basename "$(pwd)")
  local timestamp
  timestamp=$(ar_datetime)

  local tmp_probes
  tmp_probes=$(mktemp)
  trap "rm -f '${tmp_probes}'" RETURN
  printf '%s' "${probe_results_json}" > "${tmp_probes}"

  python3 - "${tmp_probes}" "${project_name}" "${timestamp}" "${AR_HARNESS_FILE}" <<'PYEOF'
import json
import sys
import math

probes_file = sys.argv[1]
project_name = sys.argv[2]
timestamp = sys.argv[3]
harness_file = sys.argv[4]

with open(probes_file, 'r') as f:
    probes = json.load(f)

# Weights per category
WEIGHTS = {
    'runtime': 1.5,
    'architecture': 1.2,
    'scriptability': 1.1,
    'harness': 1.0,
    'lint': 1.0,
    'tests': 1.0,
}

# --- Calculate overall score (average of non-skipped probes) ---
scores = []
for cat, probe in probes.items():
    if not probe.get('skipped', True) and probe.get('score') is not None:
        scores.append(probe['score'])

overall_score = round(sum(scores) / len(scores)) if scores else 0

# --- Rank improvements by impact ---
# impact = (100 - score) * weight * fixability
# fixability = min(1.0, 10.0 / max(1, estimated_iterations))
# Skip categories with score >= 95

improvements = []
for cat, probe in probes.items():
    if probe.get('skipped', True):
        continue
    score = probe.get('score')
    if score is None:
        continue
    if score >= 95:
        continue

    weight = WEIGHTS.get(cat, 1.0)
    estimated_iterations = probe.get('estimated_iterations', 1)
    fixability = min(1.0, 10.0 / max(1, estimated_iterations))
    impact = (100 - score) * weight * fixability

    # Build description from findings types count
    findings = probe.get('findings', [])
    findings_count = len(findings)
    if findings_count > 0:
        description = f"Fix {findings_count} finding{'s' if findings_count != 1 else ''} in {cat}"
    else:
        description = f"Improve {cat} (score: {score}/100)"

    improvements.append({
        'rank': 0,  # will be set after sorting
        'category': cat,
        'score': score,
        'impact': round(impact, 2),
        'description': description,
        'estimated_iterations': estimated_iterations,
        'fix_targets': probe.get('fix_targets', []),
        'tool': probe.get('tool'),
    })

# Sort by impact descending and assign ranks
improvements.sort(key=lambda x: x['impact'], reverse=True)
for i, imp in enumerate(improvements):
    imp['rank'] = i + 1

# Build harness data
harness = {
    'project': project_name,
    'timestamp': timestamp,
    'overall_score': overall_score,
    'probes': probes,
    'improvements': improvements,
}

with open(harness_file, 'w') as f:
    json.dump(harness, f, indent=2)

print(f"[autoresearch] harness.json written ({len(improvements)} improvements ranked)", file=sys.stderr)
PYEOF

  ar_log "Harness initialized: ${AR_HARNESS_FILE}"
}

# ---------------------------------------------------------------------------
# ar_harness_read
# Cats harness.json, returns error if not found.
# ---------------------------------------------------------------------------
ar_harness_read() {
  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    ar_log "ERROR: harness.json not found at ${AR_HARNESS_FILE}"
    ar_log "Run /harness:check to generate it."
    return 1
  fi
  cat "${AR_HARNESS_FILE}"
}

# ---------------------------------------------------------------------------
# ar_harness_is_stale
# Returns exit 0 if harness.json is >24h old or missing, exit 1 if fresh.
# ---------------------------------------------------------------------------
ar_harness_is_stale() {
  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    return 0
  fi

  python3 - "${AR_HARNESS_FILE}" <<'PYEOF'
import json
import sys
from datetime import datetime, timezone

harness_file = sys.argv[1]

try:
    with open(harness_file, 'r') as f:
        data = json.load(f)
    ts_str = data.get('timestamp', '')
    if not ts_str:
        sys.exit(0)  # missing timestamp → stale
    ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    age_hours = (now - ts).total_seconds() / 3600
    if age_hours > 24:
        sys.exit(0)  # stale
    else:
        sys.exit(1)  # fresh
except Exception:
    sys.exit(0)  # error reading → treat as stale
PYEOF
}

# ---------------------------------------------------------------------------
# ar_harness_print_scorecard
# Prints formatted terminal scorecard from harness.json.
# ---------------------------------------------------------------------------
ar_harness_print_scorecard() {
  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    ar_log "ERROR: harness.json not found. Run /harness:check first."
    return 1
  fi

  python3 - "${AR_HARNESS_FILE}" <<'PYEOF'
import json
import sys

harness_file = sys.argv[1]

with open(harness_file, 'r') as f:
    data = json.load(f)

project = data.get('project', 'unknown')
overall_score = data.get('overall_score', 0)
probes = data.get('probes', {})
improvements = data.get('improvements', [])

# Category display labels
LABELS = {
    'lint': 'Code Quality',
    'tests': 'Tests',
    'runtime': 'Runtime Health',
    'architecture': 'Architecture',
    'scriptability': 'Scriptability',
    'harness': 'Harness Completeness',
}

BAR_WIDTH = 20

def make_bar(score, width=BAR_WIDTH):
    filled = round(score / 100 * width)
    return '█' * filled + '░' * (width - filled)

# Separate active and skipped probes
active = []
skipped = []

for cat, probe in probes.items():
    label = LABELS.get(cat, cat.title())
    if probe.get('skipped', True):
        reason = probe.get('reason', 'skipped')
        skipped.append((label, reason))
    else:
        score = probe.get('score', 0)
        findings = probe.get('findings', [])
        active.append((cat, label, score, len(findings)))

# Sort active by score ascending (worst first)
active.sort(key=lambda x: x[2])

# Header
print(f"Harness Check Report — {project}/")
print("─" * 50)

# Scored probes
for cat, label, score, findings_count in active:
    bar = make_bar(score)
    finding_word = 'finding' if findings_count == 1 else 'findings'
    print(f"  {label:<18} {score:>3}/100  {bar}  {findings_count} {finding_word}")

print()
print(f"  Overall: {overall_score}/100")

# Skipped probes
if skipped:
    print()
    print("  Skipped:")
    for label, reason in skipped:
        print(f"    {label}: {reason}")

# Top improvements
if improvements:
    print()
    print("  Top improvements by impact:")
    for imp in improvements[:3]:
        rank = imp['rank']
        label = LABELS.get(imp['category'], imp['category'].title())
        desc = imp['description']
        print(f"  #{rank}  {label:<18} → {desc}")

# Usage hints
print()
print("  Run: /harness:improvement           (starts #1)")
if len(improvements) >= 2:
    print("  Run: /harness:improvement --rank 2  (starts #2)")
PYEOF
}

# ---------------------------------------------------------------------------
# ar_harness_to_program <rank>
# Reads harness.json, finds improvement at given rank,
# generates .autoresearch/program.md.
# ---------------------------------------------------------------------------
ar_harness_to_program() {
  local rank="${1:-1}"

  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    ar_log "ERROR: harness.json not found. Run /harness:check first."
    return 1
  fi

  local probes_lib
  probes_lib="$(find -L ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '')"
  if [ -z "${probes_lib}" ]; then
    ar_log "ERROR: harness/lib/probes.sh not found in any installed plugin"
    return 1
  fi

  python3 - "${AR_HARNESS_FILE}" "${rank}" "${AR_PROGRAM_FILE}" "${probes_lib}" <<'PYEOF'
import json
import sys

harness_file = sys.argv[1]
rank = int(sys.argv[2])
program_file = sys.argv[3]
probes_lib = sys.argv[4]

with open(harness_file, 'r') as f:
    data = json.load(f)

improvements = data.get('improvements', [])

# Find the improvement at the requested rank
target = None
for imp in improvements:
    if imp.get('rank') == rank:
        target = imp
        break

if target is None:
    print(f"[autoresearch] ERROR: No improvement found at rank {rank}", file=sys.stderr)
    sys.exit(1)

category = target['category']
score = target['score']
description = target['description']
fix_targets = target.get('fix_targets', [])
estimated_iterations = target.get('estimated_iterations', 3)
tool = target.get('tool') or 'static'

# Category display labels
LABELS = {
    'lint': 'Code Quality',
    'tests': 'Tests',
    'runtime': 'Runtime Health',
    'architecture': 'Architecture',
    'scriptability': 'Scriptability',
    'harness': 'Harness Completeness',
}
label = LABELS.get(category, category.title())

# --- Build goal ---
goal = f"Improve {label} from {score}/100. {description}."

# --- Build target files section ---
if fix_targets:
    target_files = '\n'.join(f'- {t}' for t in fix_targets[:20])
else:
    target_files = '- (detected automatically by probe)'

# --- Build eval command ---
# Sources probes.sh, runs the relevant ar_probe_<category> function,
# pipes through python3 to extract the score field.
eval_command = (
    f'source {probes_lib} && '
    f'ar_probe_{category} "{tool}" | '
    f"python3 -c \"import json,sys; d=json.load(sys.stdin); print('score:', d.get('score', 0))\""
)

# --- Threshold and max iterations ---
threshold = min(90, score + 20)
max_iterations = min(10, estimated_iterations + 3)

# --- Stopping condition ---
stopping_condition = (
    f"Score reaches {threshold}/100 or {max_iterations} iterations complete, "
    f"whichever comes first."
)

# --- Constraints ---
constraints = (
    "- Do not break existing functionality\n"
    "- Keep changes focused on the category being improved\n"
    "- One logical change per iteration"
)

# --- Metrics ---
metrics = f"- score: higher_is_better (target >= {threshold})"

# --- LLM criteria (category-specific guidance) ---
CATEGORY_GUIDANCE = {
    'scriptability': (
        "Extract long or duplicated inline shell/python blocks from markdown "
        "files (commands/agents/skills/README) into shared scripts/ or lib/ "
        "helpers. Replace the inline blocks with a single-line invocation of "
        "the extracted helper. Preserve all behavior — the helper must do "
        "exactly what the original inline block did. Prefer sourcing existing "
        "lib functions over creating new scripts when an equivalent helper "
        "already exists."
    ),
}
extra = CATEGORY_GUIDANCE.get(category, '')
llm_criteria = (
    f"The change improves {label} quality. "
    f"Score increases toward {threshold}/100. "
    "No regressions introduced."
)
if extra:
    llm_criteria = f"{llm_criteria} {extra}"

# --- Write program.md ---
program_content = f"""# Experiment Program

## Goal
{goal}

## Target Files
{target_files}

## Eval

### Method
shell_command

### Shell Command
{eval_command}

### LLM Judge Criteria
{llm_criteria}

### Metrics
{metrics}

## Stopping Condition
{stopping_condition}

## Constraints
{constraints}

## History

This file was generated by `/harness:improvement` (rank {rank}: {label}).
The experimenter agent reads this file at the start of each iteration to understand
the goal, constraints, and eval method. You can edit this file between iterations
to adjust the experiment.
"""

with open(program_file, 'w') as f:
    f.write(program_content)

print(f"[autoresearch] program.md generated for rank {rank}: {label} ({score}/100 → {threshold}/100)", file=sys.stderr)
PYEOF

  ar_log "Program generated: ${AR_PROGRAM_FILE}"
}
