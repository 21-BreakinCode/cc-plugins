#!/usr/bin/env bash
# Smoke tests for all four ar_harness_build_* functions.
set -euo pipefail

BUILD_LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/build.sh"
# shellcheck disable=SC1090
source "${BUILD_LIB}"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}

ORIG_PWD=$(pwd)

# --- feedback loop ---
echo "Test: feedback loop"
TMP=$(mktemp -d)
cd "${TMP}"
ar_harness_build_feedback_loop 'test-fb' 'PostToolUse' 'Edit' 'no untyped fns' >/dev/null
assert "hook file exists" "[ -f '${TMP}/.claude/hooks/test-fb.json' ]"
assert "hook is valid JSON" "python3 -m json.tool < '${TMP}/.claude/hooks/test-fb.json' >/dev/null"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- eval loop ---
echo "Test: eval loop"
TMP=$(mktemp -d)
cd "${TMP}"
ar_harness_build_eval_loop 'test-eval' 'descr' 'whole repo' 'criterion' >/dev/null
assert "eval file exists" "[ -f '${TMP}/eval/test-eval.sh' ]"
assert "eval is executable" "[ -x '${TMP}/eval/test-eval.sh' ]"
assert "eval is valid bash" "bash -n '${TMP}/eval/test-eval.sh'"
out_json=$("${TMP}/eval/test-eval.sh")
assert "eval prints valid JSON" "echo '${out_json}' | python3 -m json.tool >/dev/null"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- sensor ---
echo "Test: sensor"
TMP=$(mktemp -d)
cd "${TMP}"
ar_harness_build_sensor 'test-sensor' 'eslint' 'no-var' 'use let/const' >/dev/null
assert "sensor script exists" "[ -f '${TMP}/.claude/sensors/test-sensor.sh' ]"
assert "sensor doc exists"    "[ -f '${TMP}/.claude/sensors/test-sensor.SENSOR.md' ]"
assert "sensor script is bash" "bash -n '${TMP}/.claude/sensors/test-sensor.sh'"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- context report ---
echo "Test: context report"
TMP=$(mktemp -d)
cd "${TMP}"
mkdir -p .claude/agents
{ yes "padding line" || true; } | head -350 > .claude/agents/bloated.md
ar_harness_build_context_report >/dev/null
reports=( "${TMP}"/.claude/harness-report-*.md )
assert "report file exists" "[ -f '${reports[0]}' ]"
assert "report mentions bloated.md" "grep -q bloated.md '${reports[0]}'"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

echo
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
