#!/usr/bin/env bash
# End-to-end conformance for the receipts Stop hook.
# Feeds check.py synthetic transcripts and asserts the decision. The judge is
# never reached here (cheating = no tools; backed = clear anchor), so it stays
# deterministic and offline.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "${here}")"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
export CLAUDE_CONFIG_DIR="${tmp}/.claude"
mkdir -p "${CLAUDE_CONFIG_DIR}"

pass=0
fail=0

run_case() { # name expected_decision transcript_path session_id [stop_hook_active] [mode_env]
  # mode_env: extra env assignment for the check (default block); pass "" for none.
  local name="$1" expect="$2" tp="$3" sid="$4" stop="${5:-false}" mode_env="${6-CLAUDE_RECEIPTS_MODE=block}"
  local out got="approve"
  out=$(printf '{"transcript_path":"%s","session_id":"%s","stop_hook_active":%s}' "${tp}" "${sid}" "${stop}" \
        | env CLAUDE_RECEIPTS=1 ${mode_env} python3 "${root}/lib/check.py" 2>/dev/null || true)
  echo "${out}" | grep -q '"decision": *"block"' && got="block"
  if [ "${got}" = "${expect}" ]; then
    echo "ok   - ${name} (${got})"
    pass=$((pass + 1))
  else
    echo "FAIL - ${name}: expected ${expect} got ${got} :: ${out}"
    fail=$((fail + 1))
  fi
}

# 1. FACT claim, no tool calls this turn -> block
cat >"${tmp}/cheat.jsonl" <<'JSONL'
{"type":"user","isSidechain":false,"message":{"role":"user","content":"run the tests"}}
{"type":"assistant","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"**FACT:** all tests pass and the build is green."}]}}
JSONL
run_case "cheating -> block" block "${tmp}/cheat.jsonl" s1

# 2. FACT cites a file that was Read this turn -> approve
cat >"${tmp}/backed.jsonl" <<'JSONL'
{"type":"user","isSidechain":false,"message":{"role":"user","content":"look at foo"}}
{"type":"assistant","isSidechain":false,"message":{"role":"assistant","content":[{"type":"tool_use","id":"tu1","name":"Read","input":{"file_path":"src/foo.py"}}]}}
{"type":"user","isSidechain":false,"toolUseResult":{},"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu1","content":"def main(): pass  # src/foo.py"}]}}
{"type":"assistant","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"**FACT:** src/foo.py defines main."}]}}
JSONL
run_case "backed -> approve" approve "${tmp}/backed.jsonl" s2

# 3. No triggering claim at all -> approve
cat >"${tmp}/noclaim.jsonl" <<'JSONL'
{"type":"user","isSidechain":false,"message":{"role":"user","content":"hi"}}
{"type":"assistant","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"Sure, here is an overview of the options."}]}}
JSONL
run_case "no-claim -> approve" approve "${tmp}/noclaim.jsonl" s3

# 4. Same bluff, fresh session, but stop_hook_active=true (loop backstop) -> approve, not block
run_case "loop-backstop -> approve" approve "${tmp}/cheat.jsonl" s4 true

# 5. Default mode is `warn` (no MODE env, no override file): bluff flagged, not blocked.
run_case "default-warn -> approve" approve "${tmp}/cheat.jsonl" s5 false ""

# 6. A /receipts mode override file wins over the env var: file=block beats env=warn.
mkdir -p "${CLAUDE_CONFIG_DIR}/receipts"
printf 'block\n' > "${CLAUDE_CONFIG_DIR}/receipts/mode"
run_case "mode-file beats env -> block" block "${tmp}/cheat.jsonl" s6 false "CLAUDE_RECEIPTS_MODE=warn"
rm -f "${CLAUDE_CONFIG_DIR}/receipts/mode"

echo "---"
echo "pass=${pass} fail=${fail}"
[ "${fail}" -eq 0 ]
