#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/learn-state.sh"

tmp="$(mktemp -d)"
echo "Test: empty read prints nothing"
out="$(bash "$LIB" read "$tmp")"
assert "empty read is blank" '[ -z "$out" ]'

echo "Test: write then read round-trips"
sf="$(bash "$LIB" write "$tmp" "2026-08-01T12:00:00Z" "abc1234" '{"red-flags":2}')"
assert "state file created" '[ -f "$sf" ]'
got="$(bash "$LIB" read "$tmp")"
assert "last_merged_at persisted" '[ "$(echo "$got" | jq -r .last_merged_at)" = "2026-08-01T12:00:00Z" ]'
assert "last_merged_sha persisted" '[ "$(echo "$got" | jq -r .last_merged_sha)" = "abc1234" ]'
assert "counts persisted" '[ "$(echo "$got" | jq -r ".counts.\"red-flags\"")" = "2" ]'

echo "Test: write with omitted counts defaults to {}"
sf2="$(bash "$LIB" write "$tmp" "2026-08-02T00:00:00Z" "def5678")"
got2="$(bash "$LIB" read "$tmp")"
assert "omitted counts defaults to {}" '[ "$(echo "$got2" | jq -c .counts)" = "{}" ]'

rm -rf "$tmp"
finish
