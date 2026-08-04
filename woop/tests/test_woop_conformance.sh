#!/usr/bin/env bash
# Deterministic structural gate for the woop plugin. Mirrors
# session-learner/tests/. The behavioral regression — running a real WOOP and
# scoring its output — needs an agent/LLM; see README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}
has() { grep -q "$1" "$2" 2>/dev/null; }

echo "Test: woop plugin structural contract"

# --- manifest ---
PJ="${PLUGIN}/.claude-plugin/plugin.json"
assert "plugin.json exists"            "[ -f '${PJ}' ]"
assert "plugin.json name is woop"      "has '\"name\": \"woop\"' '${PJ}'"
assert "plugin.json version is 0.1.0"  "has '\"version\": \"0.1.0\"' '${PJ}'"

# --- skill ---
SKILL="${PLUGIN}/skills/woop/SKILL.md"
assert "SKILL.md exists"                 "[ -f '${SKILL}' ]"
assert "SKILL has name frontmatter"      "has '^name: woop' '${SKILL}'"
assert "SKILL has description"           "has '^description:' '${SKILL}'"
assert "SKILL names essence-wish"        "has 'essence-wish' '${SKILL}'"
assert "SKILL names the if-then reflex"  "has 'if-then reflex' '${SKILL}'"
assert "SKILL states the Obstacle rule"  "has 'Obstacle rule' '${SKILL}'"
assert "SKILL dispatches obstacle-hunter" "has 'obstacle-hunter' '${SKILL}'"
assert "SKILL has all four W/O/O/P steps" "has 'essence-wish' '${SKILL}' && has 'outcome' '${SKILL}' && has 'obstacle (always red-teamed)' '${SKILL}' && has 'if-then plan' '${SKILL}'"
assert "SKILL has persist path template" "has 'docs/woop/' '${SKILL}'"

# --- references ---
for m in prevent decide firefight retro; do
  REF="${PLUGIN}/skills/woop/references/${m}.md"
  assert "reference ${m}.md exists"          "[ -f '${REF}' ]"
  assert "reference ${m}.md names its family" "has 'Obstacle family' '${REF}'"
done

# --- command ---
CMD="${PLUGIN}/commands/woop.md"
assert "command exists" "[ -f '${CMD}' ]"
for m in prevent decide firefight retro; do
  assert "command references mode ${m}" "has '${m}' '${CMD}'"
done

# --- agent ---
AG="${PLUGIN}/agents/obstacle-hunter.md"
assert "obstacle-hunter exists"              "[ -f '${AG}' ]"
assert "obstacle-hunter is read-only (no Write)" "! has '\"Write\"' '${AG}'"
assert "obstacle-hunter is read-only (no Edit)"  "! has '\"Edit\"' '${AG}'"

# --- hygiene ---
assert "no cross-plugin 'find ~/.claude/plugins'" "! grep -rq 'find ~/.claude/plugins' '${PLUGIN}/skills' '${PLUGIN}/commands' '${PLUGIN}/agents'"

echo ""
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
