#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
FX="$DIR/fixtures"

# A conformant OKF concept: has a frontmatter block, a non-empty `type`,
# and at least one `resource:` under sources. Reserved files are exempt.
check_concept() {  # <file>
  awk 'NR==1&&/^---/{f=1;next} f&&/^---/{ok=1;exit} END{exit !ok}' "$1" || return 1
  local fm
  fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$1")"
  printf '%s\n' "$fm" | grep -qE '^type:[[:space:]]*[^[:space:]]' || return 1
  printf '%s\n' "$fm" | grep -qE 'resource:[[:space:]]*[^[:space:]]' || return 1
  return 0
}

echo "Test: golden concept is conformant"
assert "golden concept passes" 'check_concept "$FX/golden-concept.md"'

echo "Test: concept missing type is rejected"
assert "no-type concept fails" '! check_concept "$FX/bad-no-type.md"'

echo "Test: concept missing sources is rejected"
assert "no-sources concept fails" '! check_concept "$FX/bad-no-sources.md"'

finish
