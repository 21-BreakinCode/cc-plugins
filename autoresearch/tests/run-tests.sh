#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${PLUGIN_DIR}/templates/dashboard.html"
DASHBOARD_LIB="${PLUGIN_DIR}/lib/dashboard.sh"
IMPROVE_COMMAND="${PLUGIN_DIR}/commands/improve.md"
HARNESS_IMPROVEMENT_COMMAND="${PLUGIN_DIR}/commands/harness-improvement.md"
EXPERIMENT_LOOP_SKILL="${PLUGIN_DIR}/skills/experiment-loop/SKILL.md"
EXPERIMENTER_AGENT="${PLUGIN_DIR}/agents/experimenter.md"

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

assert_frontmatter_tool() {
  local file_path="$1"
  local field_name="$2"
  local tool_name="$3"
  grep -m 1 "^${field_name}:" "${file_path}" | grep -Fq "\"${tool_name}\""
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

printf 'Test: Artifact dashboard lifecycle instructions\n'
assert "improve allows Artifact" assert_frontmatter_tool "${IMPROVE_COMMAND}" "allowed-tools" "Artifact"
assert "harness-improvement allows Artifact" assert_frontmatter_tool "${HARNESS_IMPROVEMENT_COMMAND}" "allowed-tools" "Artifact"
assert "improve publishes the initial dashboard" assert_contains "${IMPROVE_COMMAND}" 'Call Artifact with:'
assert "improve initial publish uses dashboard path" assert_contains "${IMPROVE_COMMAND}" 'file_path`: `.autoresearch/dashboard.html`'
assert "improve initial publish uses required favicon" assert_contains "${IMPROVE_COMMAND}" 'favicon`: `📈`'
assert "improve initial publish uses required title" assert_contains "${IMPROVE_COMMAND}" 'title`: `Autoresearch Dashboard`'
assert "improve initial publish uses required description" assert_contains "${IMPROVE_COMMAND}" 'Live progress for the current autoresearch improvement run.'
assert "improve stops on initial Artifact failure" assert_contains "${IMPROVE_COMMAND}" 'If the initial Artifact publish fails, stop and report the error. Do not proceed to the loop.'
assert "harness-improvement publishes the initial dashboard" assert_contains "${HARNESS_IMPROVEMENT_COMMAND}" 'Call Artifact with:'
assert "harness-improvement initial publish uses dashboard path" assert_contains "${HARNESS_IMPROVEMENT_COMMAND}" 'file_path`: `.autoresearch/dashboard.html`'
assert "harness-improvement initial publish uses required favicon" assert_contains "${HARNESS_IMPROVEMENT_COMMAND}" 'favicon`: `📈`'
assert "harness-improvement initial publish uses required title" assert_contains "${HARNESS_IMPROVEMENT_COMMAND}" 'title`: `Autoresearch Dashboard`'
assert "harness-improvement initial publish uses required description" assert_contains "${HARNESS_IMPROVEMENT_COMMAND}" 'Live progress for the current autoresearch improvement run.'
assert "harness-improvement stops on initial Artifact failure" assert_contains "${HARNESS_IMPROVEMENT_COMMAND}" 'If the initial Artifact publish fails, stop and report the error. Do NOT proceed.'
assert "loop updates the stable dashboard path" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'file_path`: `.autoresearch/dashboard.html`'
assert "loop updates the stable dashboard URL" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'url`: `<dashboard_url>`'
assert "loop keeps the dashboard favicon" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'favicon`: `📈`'
assert "loop retries a publish failure once" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'retry once'
assert "loop updates after normal iterations" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'After generation succeeds, follow the Dashboard Artifact Update procedure.'
assert "loop updates after research regeneration" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'then follow the Dashboard Artifact Update procedure'
assert "loop updates after final completion" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'Follow the Dashboard Artifact Update procedure after this final generation.'
assert "loop reports the Artifact URL" assert_contains "${EXPERIMENT_LOOP_SKILL}" 'Dashboard: <dashboard_url>'
assert "experimenter can use Artifact" assert_frontmatter_tool "${EXPERIMENTER_AGENT}" "tools" "Artifact"
assert "experimenter uses the passed URL for updates" assert_contains "${EXPERIMENTER_AGENT}" 'url: <dashboard_url>` and `favicon: 📈'
assert "experimenter falls back to one publish" assert_contains "${EXPERIMENTER_AGENT}" 'publish `.autoresearch/dashboard.html` once with Artifact using `favicon: 📈`'
assert "experimenter reuses the dashboard URL" assert_contains "${EXPERIMENTER_AGENT}" 'reuse it for every later update'

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
