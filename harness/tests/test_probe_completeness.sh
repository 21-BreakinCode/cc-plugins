#!/usr/bin/env bash
# Smoke tests for ar_probe_harness.
# Run with: bash harness/tests/test_probe_completeness.sh
set -euo pipefail

PROBES_LIB="$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null)"
if [ -z "${PROBES_LIB}" ]; then
  PROBES_LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/probes.sh"
fi
# shellcheck disable=SC1090
source "${PROBES_LIB}"

PASS=0
FAIL=0

assert() {
  local name="$1"
  local cond="$2"
  if eval "${cond}"; then
    echo "  PASS  ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  ${name}  (cond: ${cond})"
    FAIL=$((FAIL + 1))
  fi
}

ORIG_PWD=$(pwd)

# --- Test 1: empty project — every "missing" signal should fire ---
echo "Test 1: empty project"
TMP=$(mktemp -d)
cd "${TMP}"
result=$(ar_probe_harness "static")
score=$(echo "${result}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["score"])')
category=$(echo "${result}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["category"])')
assert "category is 'harness'" "[ '${category}' = 'harness' ]"
assert "empty project scores < 100" "[ '${score}' -lt 100 ]"
assert "empty project scores >= 0" "[ '${score}' -ge 0 ]"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- Test 2: well-harnessed project — only 'sensor' signal may fire ---
echo "Test 2: project with hooks + evals"
TMP=$(mktemp -d)
cd "${TMP}"
mkdir -p .claude/hooks .claude/sensors eval
echo '{"name":"x"}' > .claude/hooks/x.json
echo '#!/bin/sh' > eval/x.sh
result=$(ar_probe_harness "static")
score=$(echo "${result}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["score"])')
assert "harnessed project scores >= 80" "[ '${score}' -ge 80 ]"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- Test 3: oversized agent file — context-mgmt signal fires ---
echo "Test 3: oversized agent file"
TMP=$(mktemp -d)
cd "${TMP}"
mkdir -p .claude/agents .claude/hooks .claude/sensors eval
echo '{"name":"x"}' > .claude/hooks/x.json
echo '#!/bin/sh' > eval/x.sh
{ yes "filler line" || true; } | head -350 > .claude/agents/bloated.md
result=$(ar_probe_harness "static")
findings=$(echo "${result}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(any("bloated.md" in f for f in d["findings"]))')
assert "oversized agent detected in findings" "[ '${findings}' = 'True' ]"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

echo
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
