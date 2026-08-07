#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/check-diff-coverage.sh"
export CODE_REVIEWER_GH_FIXTURE_DIR="$DIR/fixtures/gh"

cov="$(bash "$LIB" coverage 5)"
assert "src/app.ts covered" \
  '[ "$(echo "$cov" | jq -r ".files[]|select(.path==\"src/app.ts\")|.covered")" = "true" ]'
assert "lockfile excluded (uncovered)" \
  '[ "$(echo "$cov" | jq -r ".files[]|select(.path==\"package-lock.json\")|.covered")" = "false" ]'
assert "uncovered lists the lockfile" \
  '[ "$(echo "$cov" | jq -r ".uncovered[0]")" = "package-lock.json" ]'

val="$(bash "$LIB" validate 5 "$DIR/fixtures/gh/findings-5.json")"
assert "app.ts finding verified" \
  '[ "$(echo "$val" | jq -r ".[]|select(.file==\"src/app.ts\")|.location_verified")" = "true" ]'
assert "ghost.ts finding flagged" \
  '[ "$(echo "$val" | jq -r ".[]|select(.file==\"src/ghost.ts\")|.flag")" = "unverified location" ]'
finish
