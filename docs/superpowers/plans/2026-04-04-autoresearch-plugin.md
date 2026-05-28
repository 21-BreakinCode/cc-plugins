# autoresearch Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that applies autoresearch's edit-eval-keep/discard iteration loop to any user-specified improvement task, with an interactive HTML dashboard.

**Architecture:** A Claude Code plugin with a single slash command (`/autoresearch:improve`) that interactively gathers improvement goals and eval metrics, generates a `program.md` experiment spec, then spawns an `experimenter` subagent that iterates: edit target → run eval → keep or discard → update dashboard → repeat. Shell scripts in `lib/` handle dashboard generation, eval execution, and experiment logging. A self-contained HTML dashboard (Chart.js) auto-opens in the browser and auto-refreshes every 5 seconds.

**Tech Stack:** Bash (lib scripts), Markdown (commands/agents/skills), HTML + Chart.js (dashboard), JSON (experiment log)

**Spec:** `docs/superpowers/specs/2026-04-04-autoresearch-plugin-design.md`

---

## File Structure

```
autoresearch/
├── .claude-plugin/
│   └── plugin.json                          # Plugin manifest
├── commands/
│   └── improve.md                           # /autoresearch:improve slash command
├── agents/
│   └── experimenter.md                      # Subagent: autonomous edit-eval loop
├── skills/
│   └── experiment-loop/
│       └── SKILL.md                         # Core iteration logic skill
├── lib/
│   ├── common.sh                            # Shared constants, helpers, prefix: ar_
│   ├── experiment-log.sh                    # Read/write .autoresearch/experiments.json
│   ├── eval.sh                              # Run shell evals, parse scores
│   └── dashboard.sh                         # Generate dashboard HTML from experiments.json
├── templates/
│   ├── dashboard.html                       # HTML template (Chart.js, auto-refresh)
│   └── program.template.md                  # Template for generated program.md
├── CLAUDE.md                                # Plugin standards and structure
└── README.md                                # Install and usage instructions
```

**Runtime artifacts** (created in user's project):
```
.autoresearch/
├── program.md          # Generated experiment spec
├── experiments.json    # Iteration log
└── dashboard.html      # Auto-generated dashboard
```

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `autoresearch/.claude-plugin/plugin.json`
- Create: `autoresearch/CLAUDE.md`
- Create: `autoresearch/lib/common.sh`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/williamhung/Projects/cc-plugins
mkdir -p autoresearch/.claude-plugin
mkdir -p autoresearch/commands
mkdir -p autoresearch/agents
mkdir -p autoresearch/skills/experiment-loop
mkdir -p autoresearch/lib
mkdir -p autoresearch/templates
```

- [ ] **Step 2: Write plugin.json**

Create `autoresearch/.claude-plugin/plugin.json`:

```json
{
  "name": "autoresearch",
  "description": "Iterative improvement loop with eval-driven keep/discard and live HTML dashboard, inspired by karpathy/autoresearch",
  "version": "0.1.0",
  "author": {
    "name": "William Hung"
  }
}
```

- [ ] **Step 3: Write CLAUDE.md**

Create `autoresearch/CLAUDE.md`:

```markdown
# autoresearch

Claude Code plugin that applies an edit-eval-keep/discard iteration loop to any improvement task. Inspired by karpathy/autoresearch.

## Standards

- Coding: see `~/.claude/rules/coding-style.md`
- Git: see `~/.claude/rules/git-workflow.md`
- Shell scripts follow POSIX conventions with `set -euo pipefail`
- All bash functions prefixed with `ar_`

## Project Structure

- `commands/` — `/autoresearch:improve` slash command
- `agents/` — `experimenter` subagent (runs the iteration loop)
- `skills/` — `experiment-loop` skill (core iteration logic)
- `lib/` — shared shell libraries (common, experiment-log, eval, dashboard)
- `templates/` — HTML dashboard template, program.md template

## Runtime Artifacts

Created in the user's project directory under `.autoresearch/`:
- `program.md` — generated experiment spec
- `experiments.json` — structured iteration log
- `dashboard.html` — auto-refreshing HTML dashboard
```

- [ ] **Step 4: Write lib/common.sh**

Create `autoresearch/lib/common.sh`:

```bash
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
```

- [ ] **Step 5: Test common.sh functions**

```bash
cd /Users/williamhung/Projects/cc-plugins/autoresearch
source lib/common.sh
ar_log "test message"        # Should print: [autoresearch] test message
ar_date                      # Should print: 2026-04-04
ar_datetime                  # Should print ISO timestamp
ar_escape_json 'hello "world"'  # Should print: "hello \"world\""
echo $AR_PLUGIN_DIR          # Should print absolute path to autoresearch/
```

- [ ] **Step 6: Commit scaffold**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/.claude-plugin/plugin.json autoresearch/CLAUDE.md autoresearch/lib/common.sh
git commit -m "feat: scaffold autoresearch plugin with manifest, CLAUDE.md, and common lib"
```

---

### Task 2: Experiment Log Library

**Files:**
- Create: `autoresearch/lib/experiment-log.sh`

This library manages `.autoresearch/experiments.json` — initializing, appending iterations, reading state.

- [ ] **Step 1: Write experiment-log.sh**

Create `autoresearch/lib/experiment-log.sh`:

```bash
#!/usr/bin/env bash
# Experiment log management for autoresearch

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Initialize experiments.json with goal and config
# Usage: ar_log_init "goal" "eval_method" "eval_command" "llm_criteria" "max_iter" "consec_limit"
ar_log_init() {
  local goal="$1"
  local eval_method="$2"
  local eval_command="${3:-}"
  local llm_criteria="${4:-}"
  local max_iterations="${5:-10}"
  local consec_limit="${6:-3}"

  ar_ensure_dir

  local goal_json
  goal_json=$(ar_escape_json "${goal}")
  local cmd_json
  cmd_json=$(ar_escape_json "${eval_command}")
  local criteria_json
  criteria_json=$(ar_escape_json "${llm_criteria}")

  cat > "${AR_EXPERIMENTS_FILE}" <<AREOF
{
  "goal": ${goal_json},
  "baseline": null,
  "iterations": [],
  "status": "initializing",
  "config": {
    "max_iterations": ${max_iterations},
    "consecutive_non_improvements_limit": ${consec_limit},
    "eval_method": "${eval_method}",
    "eval_command": ${cmd_json},
    "llm_judge_criteria": ${criteria_json},
    "metrics": []
  }
}
AREOF

  ar_log "Initialized experiments.json"
}

# Set baseline scores
# Usage: ar_log_set_baseline '{"render_time_ms": 150}'
ar_log_set_baseline() {
  local scores_json="$1"
  local timestamp
  timestamp=$(ar_datetime)

  if ar_has_jq; then
    local tmp
    tmp=$(jq --arg ts "${timestamp}" --argjson scores "${scores_json}" \
      '.baseline = {"timestamp": $ts, "scores": $scores} | .status = "running"' \
      "${AR_EXPERIMENTS_FILE}")
    printf '%s' "${tmp}" > "${AR_EXPERIMENTS_FILE}"
  else
    python3 -c "
import json, sys
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
data['baseline'] = {'timestamp': '${timestamp}', 'scores': json.loads('${scores_json}')}
data['status'] = 'running'
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"
  fi
  ar_log "Set baseline scores"
}

# Append an experiment iteration
# Usage: ar_log_append_experiment <id> <hypothesis> <reasoning> <scores_json> <delta_json> <status> <commit_sha> <diff_summary>
ar_log_append_experiment() {
  local id="$1"
  local hypothesis="$2"
  local reasoning="$3"
  local scores_json="$4"
  local delta_json="$5"
  local status="$6"
  local commit_sha="${7:-}"
  local diff_summary="$8"
  local timestamp
  timestamp=$(ar_datetime)

  python3 -c "
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
entry = {
    'id': ${id},
    'type': 'experiment',
    'timestamp': '${timestamp}',
    'hypothesis': $(ar_escape_json "${hypothesis}"),
    'reasoning': $(ar_escape_json "${reasoning}"),
    'scores': json.loads('''${scores_json}'''),
    'delta': json.loads('''${delta_json}'''),
    'status': '${status}',
    'commit_sha': '${commit_sha}',
    'diff_summary': $(ar_escape_json "${diff_summary}")
}
data['iterations'].append(entry)
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"
  ar_log "Logged experiment iteration ${id} (${status})"
}

# Append a research entry
# Usage: ar_log_append_research <id> <query> <urls_json> <learned>
ar_log_append_research() {
  local id="$1"
  local query="$2"
  local urls_json="$3"
  local learned="$4"
  local timestamp
  timestamp=$(ar_datetime)

  python3 -c "
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
entry = {
    'id': ${id},
    'type': 'research',
    'timestamp': '${timestamp}',
    'query': $(ar_escape_json "${query}"),
    'urls': json.loads('''${urls_json}'''),
    'learned': $(ar_escape_json "${learned}")
}
data['iterations'].append(entry)
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"
  ar_log "Logged research entry ${id}"
}

# Update experiment status (running, complete, paused, error)
# Usage: ar_log_set_status "complete"
ar_log_set_status() {
  local new_status="$1"

  python3 -c "
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
data['status'] = '${new_status}'
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
"
  ar_log "Status updated to ${new_status}"
}

# Read current experiment count
ar_log_count() {
  python3 -c "
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
print(len([i for i in data['iterations'] if i['type'] == 'experiment']))
"
}

# Read consecutive non-improvement count (from tail of iterations)
ar_log_consecutive_non_improvements() {
  python3 -c "
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
experiments = [i for i in data['iterations'] if i['type'] == 'experiment']
count = 0
for exp in reversed(experiments):
    if exp['status'] == 'discarded':
        count += 1
    else:
        break
print(count)
"
}

# Read the experiments.json as raw JSON (for dashboard generation)
ar_log_read() {
  cat "${AR_EXPERIMENTS_FILE}"
}
```

- [ ] **Step 2: Test experiment-log.sh**

```bash
cd /tmp && mkdir -p test-autoresearch && cd test-autoresearch
git init
export PATH="/Users/williamhung/Projects/cc-plugins/autoresearch/lib:$PATH"
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/experiment-log.sh

# Test init
ar_log_init "Make function faster" "shell" "npm run bench" "" "10" "3"
cat .autoresearch/experiments.json  # Should show valid JSON with goal and config

# Test baseline
ar_log_set_baseline '{"render_time_ms": 150}'
cat .autoresearch/experiments.json  # Should show baseline with scores

# Test append experiment
ar_log_append_experiment 1 "Add memoization" "Sort runs every render" '{"render_time_ms": 120}' '{"render_time_ms": -30}' "kept" "abc1234" "Added useMemo"
cat .autoresearch/experiments.json  # Should show 1 iteration

# Test count
ar_log_count  # Should print: 1

# Test consecutive non-improvements
ar_log_consecutive_non_improvements  # Should print: 0

# Cleanup
cd /tmp && rm -rf test-autoresearch
```

- [ ] **Step 3: Commit experiment-log library**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/lib/experiment-log.sh
git commit -m "feat: add experiment-log library for managing experiments.json"
```

---

### Task 3: Eval Runner Library

**Files:**
- Create: `autoresearch/lib/eval.sh`

Runs the user's shell eval command, captures output, and extracts numeric scores.

- [ ] **Step 1: Write eval.sh**

Create `autoresearch/lib/eval.sh`:

```bash
#!/usr/bin/env bash
# Eval runner for autoresearch

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Run a shell eval command and capture output
# Usage: ar_eval_run "npm run benchmark"
# Prints: exit_code on first line, then full stdout+stderr
ar_eval_run() {
  local cmd="$1"
  local output
  local exit_code

  output=$(eval "${cmd}" 2>&1) && exit_code=0 || exit_code=$?

  echo "${exit_code}"
  echo "${output}"
}

# Extract a numeric value from eval output by metric name
# Looks for patterns like: metric_name: 123.45, metric_name=123.45, metric_name 123.45
# Usage: ar_eval_extract_score "render_time_ms" "$output"
# Prints: the numeric value or "null" if not found
ar_eval_extract_score() {
  local metric_name="$1"
  local output="$2"

  python3 -c "
import re, sys

metric = '${metric_name}'
output = '''${output}'''

# Try common patterns: name: value, name=value, name value (at line start or after whitespace)
patterns = [
    rf'{re.escape(metric)}[\s]*[:=]\s*([-+]?\d+\.?\d*)',
    rf'{re.escape(metric)}\s+([-+]?\d+\.?\d*)',
]

for pattern in patterns:
    match = re.search(pattern, output, re.IGNORECASE)
    if match:
        print(match.group(1))
        sys.exit(0)

print('null')
"
}

# Compare two scores given a direction
# Usage: ar_eval_is_improvement "120" "150" "lower_is_better"
# Exit code: 0 if improved, 1 if not
ar_eval_is_improvement() {
  local new_score="$1"
  local old_score="$2"
  local direction="$3"

  python3 -c "
new = float('${new_score}')
old = float('${old_score}')
direction = '${direction}'

if direction == 'lower_is_better':
    improved = new < old
else:
    improved = new > old

exit(0 if improved else 1)
"
}

# Calculate delta between two scores
# Usage: ar_eval_delta "120" "150"
# Prints: -30
ar_eval_delta() {
  local new_score="$1"
  local old_score="$2"

  python3 -c "
new = float('${new_score}')
old = float('${old_score}')
print(round(new - old, 4))
"
}
```

- [ ] **Step 2: Test eval.sh**

```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/eval.sh

# Test score extraction
ar_eval_extract_score "render_time_ms" "render_time_ms: 120.5"   # Should print: 120.5
ar_eval_extract_score "render_time_ms" "render_time_ms=95"       # Should print: 95
ar_eval_extract_score "val_bpb" "val_bpb: 0.974"                # Should print: 0.974
ar_eval_extract_score "missing" "no match here"                   # Should print: null

# Test improvement check
ar_eval_is_improvement "120" "150" "lower_is_better" && echo "improved" || echo "not improved"  # improved
ar_eval_is_improvement "160" "150" "lower_is_better" && echo "improved" || echo "not improved"  # not improved
ar_eval_is_improvement "8" "6" "higher_is_better" && echo "improved" || echo "not improved"     # improved

# Test delta
ar_eval_delta "120" "150"   # Should print: -30
ar_eval_delta "0.974" "1.003"  # Should print: -0.029
```

- [ ] **Step 3: Commit eval library**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/lib/eval.sh
git commit -m "feat: add eval runner library with score extraction and comparison"
```

---

### Task 4: Dashboard HTML Template

**Files:**
- Create: `autoresearch/templates/dashboard.html`

A self-contained HTML file with Chart.js. The `{{DATA_JSON}}` placeholder is replaced by `dashboard.sh` with the actual `experiments.json` content.

- [ ] **Step 1: Write dashboard.html template**

Create `autoresearch/templates/dashboard.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="refresh" content="5">
  <title>autoresearch dashboard</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, monospace; background: #0d1117; color: #c9d1d9; padding: 24px; }
    .header { margin-bottom: 24px; }
    .header h1 { font-size: 20px; color: #58a6ff; margin-bottom: 4px; }
    .header .goal { font-size: 14px; color: #8b949e; }
    .header .status { font-size: 14px; margin-top: 4px; }
    .status-running { color: #f0883e; }
    .status-complete { color: #3fb950; }
    .status-paused { color: #d29922; }
    .status-error { color: #f85149; }
    .summary { display: flex; gap: 24px; margin-bottom: 24px; flex-wrap: wrap; }
    .stat-card { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 16px; min-width: 140px; }
    .stat-card .label { font-size: 12px; color: #8b949e; text-transform: uppercase; }
    .stat-card .value { font-size: 24px; font-weight: bold; margin-top: 4px; }
    .stat-card .value.positive { color: #3fb950; }
    .stat-card .value.negative { color: #f85149; }
    .stat-card .value.neutral { color: #58a6ff; }
    .chart-container { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 16px; margin-bottom: 24px; }
    .chart-container h2 { font-size: 14px; color: #8b949e; margin-bottom: 12px; }
    table { width: 100%; border-collapse: collapse; background: #161b22; border: 1px solid #30363d; border-radius: 6px; overflow: hidden; }
    th { background: #1c2128; text-align: left; padding: 10px 12px; font-size: 12px; color: #8b949e; text-transform: uppercase; border-bottom: 1px solid #30363d; }
    td { padding: 10px 12px; font-size: 13px; border-bottom: 1px solid #21262d; }
    tr:last-child td { border-bottom: none; }
    tr.kept td { border-left: 3px solid #3fb950; }
    tr.discarded td { border-left: 3px solid #f85149; }
    tr.baseline td { border-left: 3px solid #58a6ff; }
    tr.research td { border-left: 3px solid #d29922; background: #1c1c0e; }
    .status-badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }
    .badge-kept { background: #0d2d0d; color: #3fb950; }
    .badge-discarded { background: #2d0d0d; color: #f85149; }
    .badge-baseline { background: #0d1d2d; color: #58a6ff; }
    .badge-research { background: #2d2d0d; color: #d29922; }
    .expandable { cursor: pointer; }
    .expandable:hover { background: #1c2128; }
    .detail-row { display: none; }
    .detail-row.open { display: table-row; }
    .detail-row td { padding: 12px 16px; background: #1c2128; font-size: 12px; white-space: pre-wrap; font-family: monospace; }
    .delta-positive { color: #f85149; }
    .delta-negative { color: #3fb950; }
    .delta-zero { color: #8b949e; }
  </style>
</head>
<body>
  <div class="header">
    <h1>autoresearch dashboard</h1>
    <div class="goal" id="goal"></div>
    <div class="status" id="status"></div>
  </div>

  <div class="summary" id="summary"></div>

  <div class="chart-container">
    <h2>Score Over Iterations</h2>
    <canvas id="scoreChart" height="80"></canvas>
  </div>

  <table id="iterationTable">
    <thead>
      <tr>
        <th>#</th>
        <th>Score</th>
        <th>Delta</th>
        <th>Status</th>
        <th>What was tried</th>
      </tr>
    </thead>
    <tbody id="iterationBody"></tbody>
  </table>

  <script>
    const DATA = {{DATA_JSON}};

    // Header
    document.getElementById('goal').textContent = 'Goal: ' + DATA.goal;
    const statusEl = document.getElementById('status');
    const experiments = DATA.iterations.filter(i => i.type === 'experiment');
    const maxIter = DATA.config.max_iterations;
    const statusText = DATA.status === 'running'
      ? `Running (iteration ${experiments.length}/${maxIter})`
      : DATA.status.charAt(0).toUpperCase() + DATA.status.slice(1);
    statusEl.textContent = 'Status: ' + statusText;
    statusEl.className = 'status status-' + DATA.status;

    // Stop auto-refresh if complete
    if (DATA.status === 'complete' || DATA.status === 'error') {
      const meta = document.querySelector('meta[http-equiv="refresh"]');
      if (meta) meta.remove();
    }

    // Summary stats
    const summaryEl = document.getElementById('summary');
    const keptExperiments = experiments.filter(e => e.status === 'kept');
    const discardedExperiments = experiments.filter(e => e.status === 'discarded');

    // Find primary metric
    const metricNames = DATA.config.metrics.length > 0
      ? DATA.config.metrics.map(m => m.name)
      : (DATA.baseline && DATA.baseline.scores ? Object.keys(DATA.baseline.scores) : []);
    const primaryMetric = metricNames[0] || 'score';
    const metricDirection = DATA.config.metrics.length > 0
      ? DATA.config.metrics[0].direction
      : 'lower_is_better';

    const baselineScore = DATA.baseline && DATA.baseline.scores ? DATA.baseline.scores[primaryMetric] : null;
    const bestExperiment = keptExperiments.length > 0
      ? keptExperiments.reduce((best, e) => {
          const s = e.scores[primaryMetric];
          const b = best.scores[primaryMetric];
          return metricDirection === 'lower_is_better' ? (s < b ? e : best) : (s > b ? e : best);
        })
      : null;
    const bestScore = bestExperiment ? bestExperiment.scores[primaryMetric] : baselineScore;

    const improvement = baselineScore && bestScore
      ? ((baselineScore - bestScore) / baselineScore * 100).toFixed(1)
      : 0;

    const cards = [
      { label: 'Baseline', value: baselineScore !== null ? baselineScore : '—', cls: 'neutral' },
      { label: 'Best', value: bestScore !== null ? bestScore : '—', cls: 'positive' },
      { label: 'Improvement', value: improvement + '%', cls: parseFloat(improvement) > 0 ? 'positive' : 'neutral' },
      { label: 'Kept / Total', value: `${keptExperiments.length} / ${experiments.length}`, cls: 'neutral' },
    ];
    cards.forEach(c => {
      summaryEl.innerHTML += `<div class="stat-card"><div class="label">${c.label}</div><div class="value ${c.cls}">${c.value}</div></div>`;
    });

    // Chart
    const chartLabels = ['Baseline', ...experiments.map((_, i) => `#${i + 1}`)];
    const chartData = [baselineScore, ...experiments.map(e => e.scores[primaryMetric])];
    const chartColors = ['#58a6ff', ...experiments.map(e => e.status === 'kept' ? '#3fb950' : '#f85149')];
    const pointStyles = ['circle', ...experiments.map(e => e.status === 'kept' ? 'circle' : 'crossRot')];

    new Chart(document.getElementById('scoreChart'), {
      type: 'line',
      data: {
        labels: chartLabels,
        datasets: [{
          label: primaryMetric,
          data: chartData,
          borderColor: '#30363d',
          backgroundColor: 'transparent',
          pointBackgroundColor: chartColors,
          pointBorderColor: chartColors,
          pointRadius: 6,
          pointHoverRadius: 8,
          pointStyle: pointStyles,
          tension: 0.1,
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => `${primaryMetric}: ${ctx.raw}`
            }
          }
        },
        scales: {
          x: { grid: { color: '#21262d' }, ticks: { color: '#8b949e' } },
          y: {
            grid: { color: '#21262d' },
            ticks: { color: '#8b949e' },
            reverse: metricDirection === 'lower_is_better'
          }
        }
      }
    });

    // Iteration table
    const tbody = document.getElementById('iterationBody');

    // Baseline row
    if (DATA.baseline) {
      tbody.innerHTML += `<tr class="baseline">
        <td>0</td>
        <td>${baselineScore !== null ? baselineScore : '—'}</td>
        <td>—</td>
        <td><span class="status-badge badge-baseline">baseline</span></td>
        <td>Baseline measurement</td>
      </tr>`;
    }

    // Iteration rows (reversed — newest first after baseline)
    const allIterations = [...DATA.iterations].reverse();
    allIterations.forEach((iter, idx) => {
      if (iter.type === 'research') {
        tbody.innerHTML += `<tr class="research expandable" onclick="toggleDetail('detail-${iter.id}')">
          <td>R</td>
          <td colspan="2">—</td>
          <td><span class="status-badge badge-research">research</span></td>
          <td>${iter.query}</td>
        </tr>
        <tr class="detail-row" id="detail-${iter.id}">
          <td colspan="5">URLs: ${(iter.urls || []).join(', ')}\nLearned: ${iter.learned}</td>
        </tr>`;
      } else {
        const score = iter.scores[primaryMetric];
        const delta = iter.delta ? iter.delta[primaryMetric] : 0;
        const deltaStr = delta > 0 ? `+${delta}` : `${delta}`;
        const deltaCls = delta < 0 && metricDirection === 'lower_is_better' ? 'delta-negative'
          : delta > 0 && metricDirection === 'higher_is_better' ? 'delta-negative'
          : delta === 0 ? 'delta-zero' : 'delta-positive';
        const statusBadge = iter.status === 'kept' ? 'badge-kept' : 'badge-discarded';
        const statusLabel = iter.status === 'kept' ? 'kept' : 'discarded';
        const rowCls = iter.status === 'kept' ? 'kept' : 'discarded';

        tbody.innerHTML += `<tr class="${rowCls} expandable" onclick="toggleDetail('detail-${iter.id}')">
          <td>${iter.id}</td>
          <td>${score}</td>
          <td class="${deltaCls}">${deltaStr}</td>
          <td><span class="status-badge ${statusBadge}">${statusLabel}</span></td>
          <td>${iter.hypothesis}</td>
        </tr>
        <tr class="detail-row" id="detail-${iter.id}">
          <td colspan="5">Reasoning: ${iter.reasoning}\nDiff: ${iter.diff_summary}${iter.commit_sha ? '\nCommit: ' + iter.commit_sha : ''}</td>
        </tr>`;
      }
    });

    function toggleDetail(id) {
      const el = document.getElementById(id);
      if (el) el.classList.toggle('open');
    }
  </script>
</body>
</html>
```

- [ ] **Step 2: Commit dashboard template**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/templates/dashboard.html
git commit -m "feat: add HTML dashboard template with Chart.js visualization"
```

---

### Task 5: Dashboard Generator Library

**Files:**
- Create: `autoresearch/lib/dashboard.sh`

Reads `experiments.json`, injects it into the HTML template, writes `dashboard.html`, and opens it.

- [ ] **Step 1: Write dashboard.sh**

Create `autoresearch/lib/dashboard.sh`:

```bash
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

  local data_json
  data_json=$(cat "${data_file}")

  # Replace {{DATA_JSON}} placeholder with actual data
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
```

- [ ] **Step 2: Test dashboard generation**

```bash
cd /tmp && mkdir -p test-autoresearch && cd test-autoresearch
git init
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/experiment-log.sh
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/dashboard.sh

# Initialize and set baseline
ar_log_init "Test goal" "shell" "echo 'score: 100'" "" "10" "3"
ar_log_set_baseline '{"score": 100}'

# Add a kept experiment
ar_log_append_experiment 1 "Try approach A" "First attempt" '{"score": 90}' '{"score": -10}' "kept" "abc1234" "Changed X to Y"

# Generate dashboard
ar_dashboard_generate && echo "SUCCESS" || echo "FAILED"

# Check output
ls -la .autoresearch/dashboard.html  # Should exist
grep "Test goal" .autoresearch/dashboard.html  # Should contain the goal

# Cleanup
cd /tmp && rm -rf test-autoresearch
```

- [ ] **Step 3: Commit dashboard generator**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/lib/dashboard.sh
git commit -m "feat: add dashboard generator library"
```

---

### Task 6: Program Template

**Files:**
- Create: `autoresearch/templates/program.template.md`

The template that the `/autoresearch:improve` command fills in to generate `.autoresearch/program.md`.

- [ ] **Step 1: Write program.template.md**

Create `autoresearch/templates/program.template.md`:

```markdown
# Experiment Program

## Goal
{{GOAL}}

## Target Files
{{TARGET_FILES}}

## Eval

### Method
{{EVAL_METHOD}}

### Shell Command
{{EVAL_COMMAND}}

### LLM Judge Criteria
{{LLM_CRITERIA}}

### Metrics
{{METRICS}}

## Stopping Condition
{{STOPPING_CONDITION}}

## Constraints
{{CONSTRAINTS}}

## History

This file was generated by `/autoresearch:improve`. The experimenter agent reads this file at the start of each iteration to understand the goal, constraints, and eval method. You can edit this file between iterations to adjust the experiment.
```

- [ ] **Step 2: Commit program template**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/templates/program.template.md
git commit -m "feat: add program.md template"
```

---

### Task 7: The `/autoresearch:improve` Command

**Files:**
- Create: `autoresearch/commands/improve.md`

The slash command entry point. Interactively gathers goal, eval, target files, stopping condition, then generates `program.md` and spawns the experimenter agent.

- [ ] **Step 1: Write improve.md**

Create `autoresearch/commands/improve.md`:

```markdown
---
description: "Iteratively improve any artifact using an edit-eval-keep/discard loop with live dashboard"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "WebSearch", "WebFetch"]
---

# /autoresearch:improve

You are the setup phase of the autoresearch plugin. Your job is to gather the information needed to run an autonomous improvement loop, generate the experiment spec, and hand off to the experimenter agent.

## Step 1: Parse the User's Input

The user invoked this command with inline content describing what they want to improve. Extract:

1. **Improvement goal** — what they want to make better
2. **Target file(s)** — if mentioned (may need to ask)
3. **Eval method** — if mentioned (may need to ask)
4. **Stopping condition** — if mentioned (may need to ask)

## Step 2: Eval Metrics Guard (MANDATORY)

**This check is non-negotiable. ALWAYS perform it.**

Scan the user's input for eval-related content: words like "score", "metric", "benchmark", "test", "measure", "judge", "rate", "evaluate", "pass", "fail", a shell command, or scoring criteria.

If NO eval method is detected, you MUST ask before proceeding:

> Before I start iterating, I need to know how to measure improvement. Please provide one or both:
>
> **Objective** — a shell command that outputs a measurable score (e.g., `npm test`, `pytest --benchmark`, `lighthouse --output json`)
>
> **Subjective** — criteria for me to judge each iteration (e.g., "rate code readability 1-10 considering naming, structure, and complexity")
>
> Without eval metrics, I can't determine if changes are improvements.

**Do NOT proceed until at least one eval method is confirmed.**

## Step 3: Interactive Gap-Filling

Ask for any missing information, one question at a time. Skip questions where the answer is already known from the user's input.

**Target file(s):**
If not specified, try to auto-detect from the goal and current project context (read nearby files, check what's relevant). If unclear, ask:
> Which file(s) should I modify during the improvement loop?

**Eval method details:**
- If shell command: confirm the exact command and which metric name to extract from output
- If LLM-as-judge: confirm the criteria and scale (default 1-10)
- If both: confirm both

**Metric direction:**
> For `<metric_name>`, is lower better or higher better?

**Stopping condition:**
> How should the loop stop?
> 1. When all metrics pass a threshold (you specify the threshold)
> 2. Smart defaults (max 10 iterations OR 3 consecutive non-improvements)
> 3. Custom (you specify max iterations and non-improvement limit)

**Constraints (optional):**
> Any constraints I should respect? (e.g., "don't change the public API", "keep bundle under 50KB")
> If none, I'll just focus on the improvement goal.

## Step 4: Generate program.md

Once all information is gathered, create the `.autoresearch/` directory and generate the experiment spec.

1. Run this to initialize the directory and gitignore:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_ensure_dir
ar_ensure_gitignore
```

2. Write `.autoresearch/program.md` with all the gathered information. Use the template at `templates/program.template.md` as a reference but fill in the actual values. Replace any `{{PLACEHOLDER}}` sections that don't apply with "N/A".

3. Initialize the experiment log:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_log_init "<goal>" "<eval_method>" "<eval_command>" "<llm_criteria>" "<max_iterations>" "<consec_limit>"
```

## Step 5: Run Baseline Eval

Before starting the loop, run the eval on the current (unmodified) target to establish the baseline score.

For shell evals:
```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/eval.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_eval_run "<eval_command>"
```

Extract the metric from the output and set the baseline:
```bash
ar_log_set_baseline '{"<metric_name>": <score>}'
```

For LLM-as-judge evals: read the target file and score it against the criteria. Record the score as the baseline.

## Step 6: Generate Initial Dashboard and Open It

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_dashboard_generate
ar_dashboard_open
```

If `ar_dashboard_generate` fails, stop and report the error. Do not proceed to the loop.

## Step 7: Hand Off to Experimenter Agent

Tell the user:
> Baseline established. Dashboard is open. Starting the improvement loop.

Then spawn the experimenter agent:

Use the Agent tool to spawn the `experimenter` agent with type from `agents/experimenter.md`. Pass the full content of `.autoresearch/program.md` and the path to `.autoresearch/experiments.json` as context in the prompt.

The prompt to the agent should include:
1. The full program.md content
2. The path to the project root
3. The paths to the lib scripts (for dashboard generation)
4. Instruction to read the experiment-loop skill for the iteration protocol

## Important Notes

- NEVER start the loop without eval metrics. This is the #1 rule.
- Ask questions ONE AT A TIME, not all at once.
- If the user provides everything upfront, skip to Step 4.
- The `.autoresearch/` directory must exist before generating the dashboard.
```

- [ ] **Step 2: Commit improve command**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/commands/improve.md
git commit -m "feat: add /autoresearch:improve slash command"
```

---

### Task 8: Experiment Loop Skill

**Files:**
- Create: `autoresearch/skills/experiment-loop/SKILL.md`

The core iteration logic that the experimenter agent follows.

- [ ] **Step 1: Write SKILL.md**

Create `autoresearch/skills/experiment-loop/SKILL.md`:

```markdown
---
name: experiment-loop
description: "Core iteration logic for autoresearch: edit target, run eval, keep or discard, update dashboard, repeat."
---

# Experiment Loop

You are running an autonomous improvement loop. Each iteration follows a strict protocol.

## Before Each Iteration

1. Read `.autoresearch/experiments.json` to understand:
   - The goal and constraints from the config
   - What has been tried before (avoid repeating failed approaches)
   - The current best score
   - How many consecutive non-improvements have occurred

2. Read the target file(s) listed in `.autoresearch/program.md`

3. Decide what to try next:
   - **If first iteration:** Make the most obvious improvement based on the goal
   - **If previous iterations improved:** Continue in a similar direction, refine further
   - **If 2+ consecutive non-improvements:** Shift strategy entirely. Don't tweak — try a fundamentally different approach.
   - **If stuck and need knowledge:** Use WebSearch + `npx defuddle parse <url> --md` to research. Log as a research entry (see Research Protocol below). This does NOT count as an iteration.

## The Iteration Protocol

### 1. Plan

Write a one-line hypothesis: what you're going to change and why you expect it to improve the metric.

### 2. Edit

Make the edit to the target file(s). **One hypothesis per iteration.** Keep changes focused and minimal. Do not combine multiple unrelated changes.

### 3. Eval

**For shell command evals:**

Run the eval command using Bash:
```bash
<eval_command> 2>&1
```

Extract the metric score from the output. Look for patterns like `metric_name: value`, `metric_name=value`, or `metric_name value`.

If the command crashes (non-zero exit without a score):
- This counts as an eval error
- Revert the edit: `git checkout -- <target_files>`
- Log the iteration as `status: "discarded"` with the error in reasoning
- If 2 consecutive eval errors, STOP and ask the user

**For LLM-as-judge evals:**

Read the modified target file. Score it against the criteria specified in program.md on a 1-10 scale. Write a one-line justification for the score.

**For composite evals:**

Run the shell command first, then do the LLM-as-judge scoring. Log both scores. Use the shell metric as the primary keep/discard signal.

### 4. Compare

Compare the new score against the previous best score (not baseline — the running best).

Calculate the delta: `new_score - previous_best_score`

Determine if this is an improvement based on the metric direction (lower_is_better or higher_is_better).

### 5. Keep or Discard

**If improved (keep):**
```bash
git add <target_files>
git commit -m "autoresearch: iteration <N> — <metric_name> <old>→<new> (kept)"
```

Log the iteration to experiments.json with `status: "kept"` and the commit SHA.

**If not improved (discard):**
```bash
git checkout -- <target_files>
```

Log the iteration to experiments.json with `status: "discarded"`. Include the diff that was attempted in `diff_summary` so the dashboard can show what was tried.

### 6. Update Dashboard

This step is **BLOCKING**. If it fails, stop the loop.

Generate the updated dashboard:
```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_dashboard_generate
```

If `ar_dashboard_generate` returns non-zero:
1. Attempt to fix the issue (e.g., re-read the template, check experiments.json validity)
2. Try generating again
3. If it still fails, STOP the loop and report: "Dashboard generation failed. Iteration paused. Error: <details>"

### 7. Check Stopping Condition

Read the config from experiments.json:
- `max_iterations`: maximum number of experiment iterations
- `consecutive_non_improvements_limit`: stop after this many consecutive discards

Check:
1. Has the experiment count reached `max_iterations`? → STOP
2. Have we hit `consecutive_non_improvements_limit` consecutive discards? → STOP
3. If config has metric thresholds, have all been met? → STOP
4. Otherwise → next iteration

### 8. Report When Done

When the loop stops, update the status:
```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_log_set_status "complete"
```

Regenerate the dashboard one final time (the auto-refresh meta tag is removed when status is "complete").

Print a summary to the user:
```
Improvement loop complete.

Baseline:     <baseline_score>
Best:         <best_score> (iteration <N>)
Improvement:  <percentage>%
Iterations:   <total> (<kept> kept, <discarded> discarded)
Reason:       <why it stopped — max iterations / convergence / threshold met>

Dashboard: .autoresearch/dashboard.html
```

## Research Protocol

When you need external knowledge during the loop:

1. Use WebSearch to find relevant URLs
2. Use Bash to run: `npx defuddle parse <url> --md`
3. Read the output and extract useful knowledge
4. Log the research:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_log_append_research <next_id> "<query>" '["<url1>", "<url2>"]' "<what you learned>"
```

5. Regenerate the dashboard (research entries show as info rows)
6. Proceed to the next iteration with the new knowledge

Research does NOT count toward the iteration limit or consecutive non-improvement count.

## Rules

- **One hypothesis per iteration.** Never combine unrelated changes.
- **Never skip eval.** Every edit must be evaluated before deciding keep/discard.
- **Never skip dashboard update.** The user must be able to see progress.
- **Always log reasoning.** The dashboard shows your thought process, not just scores.
- **Revert completely on discard.** `git checkout -- <files>` must leave the working tree identical to before the edit.
- **Compare against running best, not baseline.** The bar rises with each kept iteration.
```

- [ ] **Step 2: Commit experiment-loop skill**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/skills/experiment-loop/SKILL.md
git commit -m "feat: add experiment-loop skill with iteration protocol"
```

---

### Task 9: Experimenter Agent

**Files:**
- Create: `autoresearch/agents/experimenter.md`

The autonomous subagent spawned by the improve command.

- [ ] **Step 1: Write experimenter.md**

Create `autoresearch/agents/experimenter.md`:

```markdown
---
name: experimenter
description: "Autonomous improvement agent. Runs the edit-eval-keep/discard loop defined in program.md. Spawned by /autoresearch:improve after setup is complete. Use when the improve command hands off to start the iteration loop."
tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "WebSearch", "WebFetch"]
---

# Experimenter Agent

You are the experimenter agent for the autoresearch plugin. You run an autonomous improvement loop on target files, guided by an experiment program.

## Your Mission

You have been given a `.autoresearch/program.md` that defines:
- The improvement goal
- Which file(s) to modify
- How to evaluate each iteration (shell command, LLM-as-judge, or both)
- When to stop
- Any constraints to respect

Your job: iterate on the target files to improve them according to the eval metrics. Each iteration: edit → eval → keep or discard → update dashboard → check stop → repeat.

## How to Work

1. **Read the experiment-loop skill** for the detailed iteration protocol. The skill is located at `skills/experiment-loop/SKILL.md` within the autoresearch plugin directory. Follow it exactly.

2. **Read `.autoresearch/program.md`** to understand the goal, target files, eval method, and constraints.

3. **Read `.autoresearch/experiments.json`** to understand what has been tried before and the current state.

4. **Start the iteration loop** following the experiment-loop skill protocol.

## Key Rules

- Follow the experiment-loop skill protocol exactly
- One hypothesis per iteration
- Never skip eval or dashboard update
- Dashboard generation is BLOCKING — if it fails, stop and report
- Always revert completely on discard
- Log your reasoning for every iteration
- If you hit 2 consecutive eval errors, STOP and report to the user
- Use `npx defuddle parse <url> --md` (not WebFetch) for web research when you need external knowledge

## Accessing Library Scripts

The autoresearch lib scripts are located in the plugin directory. Source them with:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/<script>.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

Available libs:
- `common.sh` — shared constants and helpers
- `experiment-log.sh` — read/write experiments.json
- `eval.sh` — run evals, extract scores, compare
- `dashboard.sh` — generate and open the HTML dashboard
```

- [ ] **Step 2: Commit experimenter agent**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/agents/experimenter.md
git commit -m "feat: add experimenter agent for autonomous improvement loop"
```

---

### Task 10: README

**Files:**
- Create: `autoresearch/README.md`

- [ ] **Step 1: Write README.md**

Create `autoresearch/README.md`:

```markdown
# autoresearch

A Claude Code plugin that applies an autonomous edit-eval-keep/discard iteration loop to any improvement task. Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).

## How it works

1. You describe what to improve and how to measure it
2. The plugin generates an experiment spec (`program.md`)
3. An autonomous agent iterates: edit → eval → keep or discard → repeat
4. A live HTML dashboard shows scores, diffs, and reasoning in real time

## Install

Copy this plugin directory to `~/.claude/plugins/local/autoresearch/`

## Usage

```
/autoresearch:improve <describe what you want to improve>
```

The command will interactively ask for:
- **Eval metrics** (required) — a shell command, LLM-judge criteria, or both
- **Target file(s)** — which files to modify
- **Stopping condition** — when to stop iterating

### Examples

**Optimize a function with a benchmark:**
```
/autoresearch:improve make the sort function in src/utils/sort.ts faster. Eval: npm run benchmark, metric: sort_time_ms (lower is better). Stop after 10 iterations.
```

**Improve code readability with LLM-as-judge:**
```
/autoresearch:improve improve readability of src/services/auth.ts
```
(The command will ask you for eval criteria since none were provided.)

**Improve prompt quality with composite eval:**
```
/autoresearch:improve optimize the system prompt in prompts/classifier.md. Shell eval: python eval_prompt.py, metric: accuracy (higher is better). Also judge: rate clarity and specificity 1-10.
```

## Runtime artifacts

Created in your project under `.autoresearch/` (gitignored automatically):

| File | Purpose |
|---|---|
| `program.md` | Experiment spec — human-readable, editable between iterations |
| `experiments.json` | Structured log of all iterations |
| `dashboard.html` | Auto-refreshing HTML dashboard — opens automatically |

## Dashboard

The dashboard auto-opens in your browser and refreshes every 5 seconds. It shows:
- Score chart with kept (green) vs discarded (red) iterations
- Iteration log with expandable diffs and reasoning
- Summary stats: baseline, best score, improvement %, kept/total ratio
- Research entries when the agent looked something up

## Eval methods

| Method | When to use | Example |
|---|---|---|
| Shell command | You have a benchmark, test suite, or scoring script | `pytest --benchmark`, `npm run perf` |
| LLM-as-judge | Subjective quality (readability, clarity, style) | "rate readability 1-10" |
| Composite | Both objective and subjective metrics | benchmark + readability score |

## Configuration

Edit `.autoresearch/program.md` between iterations to adjust the goal, constraints, or eval criteria. The agent re-reads it at the start of each iteration.
```

- [ ] **Step 2: Commit README**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/README.md
git commit -m "docs: add autoresearch README with usage examples"
```

---

### Task 11: End-to-End Smoke Test

**Files:**
- No new files — tests the full flow

- [ ] **Step 1: Verify plugin structure**

```bash
cd /Users/williamhung/Projects/cc-plugins/autoresearch
tree .
```

Expected output:
```
.
├── .claude-plugin
│   └── plugin.json
├── CLAUDE.md
├── README.md
├── agents
│   └── experimenter.md
├── commands
│   └── improve.md
├── lib
│   ├── common.sh
│   ├── dashboard.sh
│   ├── eval.sh
│   └── experiment-log.sh
├── skills
│   └── experiment-loop
│       └── SKILL.md
└── templates
    ├── dashboard.html
    └── program.template.md
```

- [ ] **Step 2: Test full lib pipeline in isolation**

```bash
cd /tmp && mkdir -p test-autoresearch-e2e && cd test-autoresearch-e2e
git init

# Source all libs
PLUGIN_DIR="/Users/williamhung/Projects/cc-plugins/autoresearch"
source "${PLUGIN_DIR}/lib/common.sh"
source "${PLUGIN_DIR}/lib/experiment-log.sh"
source "${PLUGIN_DIR}/lib/eval.sh"
source "${PLUGIN_DIR}/lib/dashboard.sh"

# 1. Initialize
ar_ensure_dir
ar_ensure_gitignore
ar_log_init "Reduce sort time" "shell" "echo 'sort_time_ms: 150'" "" "5" "3"

# 2. Set baseline
ar_log_set_baseline '{"sort_time_ms": 150}'

# 3. Add a kept experiment
ar_log_append_experiment 1 "Use quicksort instead of bubblesort" "Bubblesort is O(n^2)" '{"sort_time_ms": 95}' '{"sort_time_ms": -55}' "kept" "abc1234" "Replaced bubblesort with quicksort"

# 4. Add a discarded experiment
ar_log_append_experiment 2 "Try radix sort" "Might be faster for integers" '{"sort_time_ms": 100}' '{"sort_time_ms": 5}' "discarded" "" "Replaced quicksort with radix sort"

# 5. Add a research entry
ar_log_append_research 3 "fastest sorting algorithms for small arrays" '["https://example.com/sort"]' "Insertion sort is fastest for n<20"

# 6. Add another kept experiment
ar_log_append_experiment 4 "Hybrid: quicksort + insertion for small partitions" "Research showed insertion sort best for n<20" '{"sort_time_ms": 82}' '{"sort_time_ms": -13}' "kept" "def5678" "Added insertion sort cutoff at n=16"

# 7. Generate dashboard
ar_dashboard_generate && echo "Dashboard generated successfully" || echo "Dashboard generation FAILED"

# 8. Verify
cat .autoresearch/experiments.json | python3 -m json.tool > /dev/null && echo "JSON valid" || echo "JSON invalid"
grep "sort_time_ms" .autoresearch/dashboard.html > /dev/null && echo "Dashboard contains metric" || echo "Dashboard missing metric"
grep "Chart.js" .autoresearch/dashboard.html > /dev/null && echo "Dashboard has Chart.js" || echo "Dashboard missing Chart.js"

# 9. Check counts
echo "Experiment count: $(ar_log_count)"                          # Should print: 3
echo "Consecutive non-improvements: $(ar_log_consecutive_non_improvements)"  # Should print: 0

# 10. Check eval helpers
ar_eval_extract_score "sort_time_ms" "sort_time_ms: 82"           # Should print: 82
ar_eval_is_improvement "82" "95" "lower_is_better" && echo "Is improvement" || echo "Not improvement"  # Should print: Is improvement
ar_eval_delta "82" "95"                                            # Should print: -13

echo "All smoke tests passed"

# Cleanup
cd /tmp && rm -rf test-autoresearch-e2e
```

- [ ] **Step 3: Commit — final verification**

```bash
cd /Users/williamhung/Projects/cc-plugins
git status
git log --oneline -10
```

Verify all commits are present and the working tree is clean.
