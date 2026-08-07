#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/mine-git-signals.sh"

tmp="$(mktemp -d)"; ( cd "$tmp"
  git init -q && git config user.email t@t && git config user.name t
  echo a >  f1; git add .; git commit -qm "feat: add f1"
  echo b >> f1; git add .; git commit -qm "fix: correct f1 bug"
  echo c >  f2; git add .; git commit -qm "feat: add f2"
  echo d >> f1; git add .; git commit -qm 'Revert "feat: add f1"'
)
out="$(cd "$tmp" && bash "$LIB" 2000-01-01)"
assert "one revert found"      '[ "$(echo "$out" | jq ".reverts|length")" = "1" ]'
assert "at least one hotfix"   '[ "$(echo "$out" | jq ".hotfixes|length")" -ge "1" ]'
assert "f1 is top churn file"  '[ "$(echo "$out" | jq -r ".churn[0].file")" = "f1" ]'
rm -rf "$tmp"
finish
