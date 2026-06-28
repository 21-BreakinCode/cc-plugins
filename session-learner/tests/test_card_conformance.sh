#!/usr/bin/env bash
# Regression check for the per-card Zettelkasten contract enforced by
# session-learner's pick-up skill. Scores the committed golden reference cards
# against the 6 mechanical rules and asserts full conformance.
#
# This is the deterministic part. The full regression after editing the skills
# (regenerate cards from the fixture, then re-score) needs an agent/LLM — see
# README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SCORER="${SCRIPT_DIR}/score_cards.sh"
GOLDEN="${SCRIPT_DIR}/fixtures/golden-cards"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}

echo "Test: golden cards satisfy the per-card contract"
OUT="$(bash "${SCORER}" "${GOLDEN}")"
echo "${OUT}" | sed 's/^/    /'

obj="$(printf '%s\n' "${OUT}" | sed -n 's/^objective_score: //p')"
hard="$(printf '%s\n' "${OUT}" | sed -n 's/^hard_violations: //p')"
ncards="$(printf '%s\n' "${OUT}" | sed -n 's/^num_cards: //p')"

assert "objective_score is 10.0" "[ \"${obj}\" = '10.0' ]"
assert "hard_violations is 0"    "[ \"${hard}\" = '0' ]"
assert "found 3 golden cards"    "[ \"${ncards}\" = '3' ]"

echo ""
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
