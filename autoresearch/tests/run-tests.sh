#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${PLUGIN_DIR}/templates/dashboard.html"
DASHBOARD_LIB="${PLUGIN_DIR}/lib/dashboard.sh"

PASS=0
FAIL=0

assert() {
  local description="$1"
  shift

  if "$@"; then
    printf '  PASS  %s\n' "${description}"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s\n' "${description}"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local file_path="$1"
  local expected_text="$2"
  grep -Fq -- "${expected_text}" "${file_path}"
}

assert_not_contains() {
  local file_path="$1"
  local unexpected_text="$2"
  ! grep -Fq -- "${unexpected_text}" "${file_path}"
}

printf 'Test: dashboard artifact fragment\n'
assert "keeps the required title" assert_contains "${TEMPLATE}" "<title>Autoresearch Dashboard</title>"
assert "uses an inline SVG chart" assert_contains "${TEMPLATE}" '<svg id="scoreChart" viewBox="0 0 720 220" role="img" aria-label="Score over iterations"></svg>'
assert "renders the SVG chart" assert_contains "${TEMPLATE}" 'function renderScoreChart()'
assert "has no remote assets" bash -c '! grep -Eq "https?://|//cdn\." "$1"' _ "${TEMPLATE}"
assert "has no Chart.js renderer" assert_not_contains "${TEMPLATE}" 'new Chart('
assert "has no refresh markup" bash -c '! grep -Eqi "http-equiv=\\\"refresh\\\"|meta\\[http-equiv=\\\"refresh\\\"\\]" "$1"' _ "${TEMPLATE}"
assert "has no page wrappers" bash -c '! grep -Eqi "<!doctype|<html|</html>|<head|</head>|<body|</body>" "$1"' _ "${TEMPLATE}"
assert "has no dashboard open helper" assert_not_contains "${DASHBOARD_LIB}" 'ar_dashboard_open'

printf 'Test: dashboard generation\n'
TEMPORARY_DIRECTORY="$(mktemp -d)"
cleanup() {
  rm -rf "${TEMPORARY_DIRECTORY}"
}
trap cleanup EXIT

ORIGINAL_DIRECTORY="$(pwd)"
cd "${TEMPORARY_DIRECTORY}"
mkdir -p .autoresearch
printf '%s' '{"goal":"test goal"}' > .autoresearch/experiments.json
# shellcheck disable=SC1090
source "${DASHBOARD_LIB}"
ar_dashboard_generate
assert "injects dashboard data" assert_contains "${AR_DASHBOARD_FILE}" '"goal":"test goal"'
cd "${ORIGINAL_DIRECTORY}"

printf '\nPassed: %s  Failed: %s\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
