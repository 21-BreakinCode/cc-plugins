#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
ROOT="$DIR/.."
A="$ROOT/agents"
CONTRACT="$ROOT/references/review-contract.md"

fm() { awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$1"; }
fm_value() { fm "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

echo "Test: shared contract"
assert "contract exists" '[ -f "$CONTRACT" ]'
assert "contract has PR-head fallback (Review Focus 5)" 'grep -q "cat-file -e" "$CONTRACT" && grep -q "only source of truth" "$CONTRACT"'
assert "contract forbids repo writes" 'grep -q "git checkout" "$CONTRACT"'
assert "contract defines none" 'grep -q "output exactly \`none\`" "$CONTRACT"'

check_reviewer() {  # <name> <model>
  local agent_name="$1" agent_model="$2"
  local f="$A/$agent_name.md"
  assert "$agent_name exists" '[ -f "$f" ]'
  [ -f "$f" ] || return 0
  assert "$agent_name name" '[ "$(fm_value "$f" name)" = "$agent_name" ]'
  assert "$agent_name model $agent_model" '[ "$(fm_value "$f" model)" = "$agent_model" ]'
  assert "$agent_name tools Read,Bash only" '[ "$(fm_value "$f" tools)" = "[\"Read\", \"Bash\"]" ]'
  assert "$agent_name reads contract" 'grep -q "\${CLAUDE_PLUGIN_ROOT}/references/review-contract.md" "$f"'
}

echo "Test: reviewer agents"
check_reviewer correctness-reviewer opus
check_reviewer test-reviewer sonnet
check_reviewer security-reviewer sonnet
check_reviewer ops-reviewer sonnet
check_reviewer simplicity-reviewer sonnet
check_reviewer policy-reviewer opus

echo "Test: orchestrator"
O="$A/pr-review-orchestrator.md"
assert "orchestrator model sonnet" '[ "$(fm_value "$O" model)" = "sonnet" ]'
assert "orchestrator tools" '[ "$(fm_value "$O" tools)" = "[\"Bash\", \"Read\", \"Agent\"]" ]'
assert "orchestrator passes the diff by path" 'grep -q "DIFF_FILE=" "$O"'
assert "orchestrator uses new resolver" 'grep -q "lib/resolve-policy-dir.sh" "$O"'
assert "orchestrator has no AskUserQuestion" '! grep -q "AskUserQuestion" "$O"'

echo "Test: no cross-plugin references (plugin-rules §2)"
assert "no pr-review-toolkit outside CHANGELOG" '! grep -rn "pr-review-toolkit" "$ROOT" --include=*.md --include=*.sh --include=*.json | grep -v CHANGELOG.md | grep -q .'

finish
