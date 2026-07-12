#!/usr/bin/env bash
# Regression check for humanize's core output invariants:
#   - English output contains zero em/en dashes.
#   - zh-TW output uses no Mainland-vocab tells and no half-width sentence commas.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
EN="${DIR}/fixtures/en-after.md"
ZH="${DIR}/fixtures/zhtw-after.md"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}

# English: no em-dash (—), en-dash (–), or double-hyphen (--)
assert "en-after has no em/en dash"      "! grep -qE '—|–|--' '${EN}'"

# zh-TW: none of a small set of Mainland-vocab tells
assert "zhtw-after has no Mainland vocab" "! grep -qE '視頻|質量|信息|網絡|屏幕|智能|默認' '${ZH}'"

# zh-TW: uses full-width comma somewhere (sanity that punctuation is Chinese-style)
assert "zhtw-after uses full-width comma" "grep -q '，' '${ZH}'"

echo ""
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
