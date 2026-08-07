#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
GOLDEN="$DIR/fixtures/golden-entry.md"

# Every '### ' entry must be followed (within its block) by an Evidence line
# carrying a PR#, a 7+ hex SHA, or an http URL.
check_evidence() {  # <file>
  awk '
    /^### /      { if (title!="" && !ok) exit 1; title=$0; ok=0 }
    /^- \*\*Evidence:\*\*/ {
      if ($0 ~ /PR #[0-9]+/ || $0 ~ /[0-9a-f]{7,}/ || $0 ~ /http/) ok=1
    }
    END { if (title!="" && !ok) exit 1 }
  ' "$1"
}
echo "Test: golden entry satisfies the evidence rule"
assert "golden entry has valid evidence" 'check_evidence "$GOLDEN"'

echo "Test: an entry with no evidence fails"
bad="$(mktemp)"; printf '### no evidence\n- **What:** x\n' > "$bad"
assert "evidence-less entry rejected" '! check_evidence "$bad"'
rm -f "$bad"
finish
