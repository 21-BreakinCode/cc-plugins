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
  printf 'gen.md linguist-generated=true\n' > .gitattributes; git add .gitattributes; git commit -qm "chore: mark gen.md generated"
  for i in 1 2 3 4 5; do echo "g$i" >> gen.md; git add gen.md; git commit -qm "regen $i"; done
  mkdir -p dist; for i in 1 2 3 4; do echo "b$i" >> dist/bundle.js; git add dist/bundle.js; git commit -qm "build $i"; done
)
out="$(cd "$tmp" && bash "$LIB" 2000-01-01)"
assert "one revert found"      '[ "$(echo "$out" | jq ".reverts|length")" = "1" ]'
assert "at least one hotfix"   '[ "$(echo "$out" | jq ".hotfixes|length")" -ge "1" ]'
assert "f1 is top churn file"  '[ "$(echo "$out" | jq -r ".churn[0].file")" = "f1" ]'
assert "linguist-generated file excluded from churn" '[ "$(echo "$out" | jq "[.churn[].file]|index(\"gen.md\")")" = "null" ]'
assert "dist/ file excluded from churn"              '[ "$(echo "$out" | jq "[.churn[].file]|index(\"dist/bundle.js\")")" = "null" ]'
rm -rf "$tmp"
finish
