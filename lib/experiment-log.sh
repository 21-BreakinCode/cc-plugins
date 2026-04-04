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
    python3 - <<PYEOF
import json, sys
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
data['baseline'] = {'timestamp': '${timestamp}', 'scores': json.loads('''${scores_json}''')}
data['status'] = 'running'
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
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

  local hypothesis_json
  hypothesis_json=$(ar_escape_json "${hypothesis}")
  local reasoning_json
  reasoning_json=$(ar_escape_json "${reasoning}")
  local diff_summary_json
  diff_summary_json=$(ar_escape_json "${diff_summary}")

  python3 - <<PYEOF
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
entry = {
    'id': ${id},
    'type': 'experiment',
    'timestamp': '${timestamp}',
    'hypothesis': ${hypothesis_json},
    'reasoning': ${reasoning_json},
    'scores': json.loads('''${scores_json}'''),
    'delta': json.loads('''${delta_json}'''),
    'status': '${status}',
    'commit_sha': '${commit_sha}',
    'diff_summary': ${diff_summary_json}
}
data['iterations'].append(entry)
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF

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

  local query_json
  query_json=$(ar_escape_json "${query}")
  local learned_json
  learned_json=$(ar_escape_json "${learned}")

  python3 - <<PYEOF
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
entry = {
    'id': ${id},
    'type': 'research',
    'timestamp': '${timestamp}',
    'query': ${query_json},
    'urls': json.loads('''${urls_json}'''),
    'learned': ${learned_json}
}
data['iterations'].append(entry)
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF

  ar_log "Logged research entry ${id}"
}

# Update experiment status (running, complete, paused, error)
# Usage: ar_log_set_status "complete"
ar_log_set_status() {
  local new_status="$1"

  python3 - <<PYEOF
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
data['status'] = '${new_status}'
with open('${AR_EXPERIMENTS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF

  ar_log "Status updated to ${new_status}"
}

# Read current experiment count
ar_log_count() {
  python3 - <<PYEOF
import json
with open('${AR_EXPERIMENTS_FILE}', 'r') as f:
    data = json.load(f)
print(len([i for i in data['iterations'] if i['type'] == 'experiment']))
PYEOF
}

# Read consecutive non-improvement count (from tail of iterations)
ar_log_consecutive_non_improvements() {
  python3 - <<PYEOF
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
PYEOF
}

# Read the experiments.json as raw JSON (for dashboard generation)
ar_log_read() {
  cat "${AR_EXPERIMENTS_FILE}"
}
