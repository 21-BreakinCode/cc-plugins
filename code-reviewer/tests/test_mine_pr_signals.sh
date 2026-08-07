#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/mine-pr-signals.sh"
export CODE_REVIEWER_GH_FIXTURE_DIR="$DIR/fixtures/gh"

out="$(bash "$LIB" main 2026-01-01)"
assert "one merged PR" '[ "$(echo "$out" | jq length)" = "1" ]'
assert "outdated comment caused_change=true" \
  '[ "$(echo "$out" | jq -r ".[0].comments[]|select(.url==\"https://x/c1\")|.caused_change")" = "true" ]'
assert "current comment caused_change=false" \
  '[ "$(echo "$out" | jq -r ".[0].comments[]|select(.url==\"https://x/c2\")|.caused_change")" = "false" ]'
assert "review state carried" \
  '[ "$(echo "$out" | jq -r ".[0].reviews[0].state")" = "CHANGES_REQUESTED" ]'
finish
