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

  python3 - <<PYEOF
import re, sys

metric = """${metric_name}"""
output = """${output}"""

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
PYEOF
}

# Compare two scores given a direction
# Usage: ar_eval_is_improvement "120" "150" "lower_is_better"
# Exit code: 0 if improved, 1 if not
ar_eval_is_improvement() {
  local new_score="$1"
  local old_score="$2"
  local direction="$3"

  python3 - <<PYEOF
new = float("""${new_score}""")
old = float("""${old_score}""")
direction = """${direction}"""

if direction == 'lower_is_better':
    improved = new < old
else:
    improved = new > old

exit(0 if improved else 1)
PYEOF
}

# Calculate delta between two scores
# Usage: ar_eval_delta "120" "150"
# Prints: -30
ar_eval_delta() {
  local new_score="$1"
  local old_score="$2"

  python3 - <<PYEOF
new = float("""${new_score}""")
old = float("""${old_score}""")
print(round(new - old, 4))
PYEOF
}
