#!/usr/bin/env bash
# Smoke tests for blind paired judging (lib/judge.sh) and min_delta
# (ar_eval_is_improvement, ar_log_init).
set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/.." && pwd)/lib"
# shellcheck disable=SC1090
source "${LIB_DIR}/judge.sh"
# shellcheck disable=SC1090
source "${LIB_DIR}/eval.sh"
# shellcheck disable=SC1090
source "${LIB_DIR}/experiment-log.sh"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}

ORIG_PWD=$(pwd)
TMP=$(mktemp -d)
cd "${TMP}"

echo "Test: stage puts kept and edited versions under blind labels"
mkdir -p docs
printf 'kept version\n' > docs/guide.md
ar_snapshot_save docs/guide.md
printf 'edited version\n' > docs/guide.md
edited_1=$(ar_judge_stage 1 docs/guide.md 2>/dev/null)
edited_2=$(ar_judge_stage 2 docs/guide.md 2>/dev/null)
assert "odd judge sees the edit as A" "[ '${edited_1}' = 'A' ]"
assert "even judge sees the edit as B" "[ '${edited_2}' = 'B' ]"
assert "judge 1 A holds the edit" "[ \"\$(cat .autoresearch/judge/1/A/docs/guide.md)\" = 'edited version' ]"
assert "judge 1 B holds the kept version" "[ \"\$(cat .autoresearch/judge/1/B/docs/guide.md)\" = 'kept version' ]"
assert "judge 2 A holds the kept version" "[ \"\$(cat .autoresearch/judge/2/A/docs/guide.md)\" = 'kept version' ]"
assert "staging leaves the target untouched" "[ \"\$(cat docs/guide.md)\" = 'edited version' ]"

echo "Test: stage rejects bad input"
assert "missing judge id fails" "! ar_judge_stage '' docs/guide.md 2>/dev/null"
assert "non-numeric judge id fails" "! ar_judge_stage x docs/guide.md 2>/dev/null"
assert "no target files fails" "! ar_judge_stage 1 2>/dev/null"
assert "target without snapshot fails" "printf 'x\n' > new.md; ! ar_judge_stage 1 new.md 2>/dev/null"

echo "Test: tally needs a strict majority preferring the edit"
assert "3 better keeps" "[ \"\$(ar_judge_tally A:A B:B A:A)\" = '{\"better\": 3, \"worse\": 0, \"tie\": 0, \"keep\": true}' ]"
assert "2 better 1 worse keeps" "ar_judge_tally A:A B:B A:B | grep -q '\"keep\": true'"
assert "1 better 2 ties discards" "ar_judge_tally A:A B:tie A:tie | grep -q '\"keep\": false'"
assert "half of an even panel is not a majority" "ar_judge_tally A:A B:tie | grep -q '\"keep\": false'"
assert "all ties discard" "ar_judge_tally A:tie B:tie A:tie | grep -q '\"keep\": false'"
assert "kept-version votes count as worse" "[ \"\$(ar_judge_tally A:B B:A A:A)\" = '{\"better\": 1, \"worse\": 2, \"tie\": 0, \"keep\": false}' ]"
assert "invalid verdict fails" "! ar_judge_tally A:maybe 2>/dev/null"
assert "invalid edited label fails" "! ar_judge_tally C:A 2>/dev/null"
assert "no votes fails" "! ar_judge_tally 2>/dev/null"

echo "Test: min_delta discards gains at or below it"
assert "default 0 keeps any gain" "ar_eval_is_improvement 10.01 10 higher_is_better"
assert "default 0 discards an equal score" "! ar_eval_is_improvement 10 10 higher_is_better"
assert "gain below min_delta discarded" "! ar_eval_is_improvement 10.05 10 higher_is_better 0.1"
assert "gain above min_delta kept" "ar_eval_is_improvement 10.2 10 higher_is_better 0.1"
assert "lower_is_better respects min_delta" "! ar_eval_is_improvement 99.95 100 lower_is_better 0.1"
assert "lower_is_better keeps a real drop" "ar_eval_is_improvement 99 100 lower_is_better 0.1"

echo "Test: ar_log_init stores min_delta"
ar_log_init "goal" "shell" "true" "" 10 3 ".1" 2>/dev/null
assert "min_delta saved as valid JSON number" "python3 -c 'import json; assert json.load(open(\".autoresearch/experiments.json\"))[\"config\"][\"min_delta\"] == 0.1'"
ar_log_init "goal" "shell" "true" "" 10 3 2>/dev/null
assert "min_delta defaults to 0" "python3 -c 'import json; assert json.load(open(\".autoresearch/experiments.json\"))[\"config\"][\"min_delta\"] == 0'"
assert "non-numeric min_delta fails" "! ar_log_init goal shell true '' 10 3 abc 2>/dev/null"

cd "${ORIG_PWD}"
rm -rf "${TMP}"

echo ""
echo "  ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
