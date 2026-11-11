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
assert "contract defines none" 'grep -q "findings part is exactly \`none\`" "$CONTRACT"'

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
assert "orchestrator tools" '[ "$(fm_value "$O" tools)" = "[\"Bash\", \"Read\", \"Write\", \"Agent\"]" ]'
assert "orchestrator passes the diff by path" 'grep -q "DIFF_FILE=" "$O"'
assert "orchestrator uses new resolver" 'grep -q "lib/resolve-policy-dir.sh" "$O"'
assert "orchestrator has no AskUserQuestion" '! grep -q "AskUserQuestion" "$O"'
assert "Phase 5 does not reuse \$REVIEW_DIR" '! sed -n "/^## Phase 5/,\$p" "$O" | grep -qF "\$REVIEW_DIR"'
assert "Phase 1 prints labeled DIFF_FILE" 'grep -qF "DIFF_FILE=%s" "$O"'
assert "contract defines error output" 'grep -qF "error:" "$CONTRACT"'
assert "orchestrator shows agent errors" 'grep -qF "=error" "$O"'
assert "orchestrator runs the base drift check" 'grep -q "lib/check-base-drift.sh" "$O"'
assert "orchestrator gives MERGED_TREE to correctness" 'grep -q "^MERGED_TREE=.*correctness-reviewer only" "$O"'
assert "orchestrator writes findings with ids and refs" 'grep -q "\"id\": .*\"refs\": \[" "$O"'
assert "orchestrator writes report.md and pr.json" 'grep -qF "<REVIEW_DIR>/report.md" "$O" && grep -qF "/pr.json" "$O"'
assert "orchestrator never prints the gh token" 'grep -qF "Never print the token" "$O"'

echo "Test: evidence refs (review page)"
assert "contract finding format has Ref lines" 'grep -q "^  Ref: <evidence ref>" "$CONTRACT"'
for form in '`code <path>:<start>-<end>`' '`diff <path> "<text>"`' '`grep [-w]' '`merge-tree`' '@merged'; do
  assert "contract defines ref form $form" 'grep -qF "$form" "$CONTRACT"'
done
assert "correctness searches the test merge" 'grep -q "merge-drift" "$A/correctness-reviewer.md" && grep -q "MERGED_TREE" "$A/correctness-reviewer.md"'

echo "Test: review page builder agent"
P="$A/review-page-builder.md"
assert "page builder exists" '[ -f "$P" ]'
assert "page builder name" '[ "$(fm_value "$P" name)" = "review-page-builder" ]'
assert "page builder model opus" '[ "$(fm_value "$P" model)" = "opus" ]'
assert "page builder tools Read,Bash,Write" '[ "$(fm_value "$P" tools)" = "[\"Read\", \"Bash\", \"Write\"]" ]'
assert "page builder reads contract" 'grep -q "\${CLAUDE_PLUGIN_ROOT}/references/review-contract.md" "$P"'
assert "page builder runs the builder script" 'grep -q "\${CLAUDE_PLUGIN_ROOT}/lib/build-review-page.py" "$P"'
assert "page builder draws before and after diagrams" 'grep -q "Draw the architecture before and after" "$P" && grep -qF "@base" "$P"'
assert "am CLI is bundled with its license" '[ -f "$ROOT/lib/am.mjs" ] && grep -q "MIT License" "$ROOT/lib/am.LICENSE"'
assert "contract defines the @base ref" 'grep -qF "@base" "$CONTRACT"'

echo "Test: command builds a local page and posts from the reply"
C="$ROOT/commands/review-pr.md"
assert "command dispatches the page builder" 'grep -q "code-reviewer:review-page-builder" "$C"'
assert "command checks for Node.js 20" 'grep -q "node --version" "$C" && grep -q "Node.js 20 or newer" "$C"'
assert "command opens the local page" 'grep -qF "open \"<PAGE_FILE>\"" "$C" && grep -q "Nothing is published" "$C"'
assert "command reads the reply by tag" 'grep -qF "[<finding id>] Your call on this finding?" "$C" && grep -qF "[review] GitHub action?" "$C"'
assert "every run is a new review" 'grep -q "Every run is a new review" "$C"'
assert "command never switches the gh account" 'grep -qF "Never run \`gh auth switch\`" "$C"'
assert "command never posts without approval" 'grep -q "Never post without approval" "$C"'
assert "command uses no Artifact tools" '! fm "$C" | grep -q "Artifact"'

echo "Test: no cross-plugin references (plugin-rules §2)"
assert "no pr-review-toolkit outside CHANGELOG" '! grep -rn "pr-review-toolkit" "$ROOT" --include=*.md --include=*.sh --include=*.json | grep -v CHANGELOG.md | grep -q .'

finish
