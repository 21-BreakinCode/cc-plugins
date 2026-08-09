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
assert "revert_chains empty (no chain)" '[ "$(echo "$out" | jq ".revert_chains|length")" = "0" ]'
rm -rf "$tmp"

# revert chain detection: revert A, then revert the revert → misdiagnosis signal
tmp2="$(mktemp -d)"; ( cd "$tmp2"
  git init -q && git config user.email t@t && git config user.name t
  echo a > f1; git add .; git commit -qm "feat: init"
  echo b > f1; git add .; git commit -qm "fix: pin alpine to 3.20"
  pin_sha="$(git rev-parse HEAD)"
  git revert --no-edit HEAD   # Revert "fix: pin alpine to 3.20"
  revert_sha="$(git rev-parse HEAD)"
  git revert --no-edit HEAD   # Revert "Revert "fix: pin alpine to 3.20""
)
out2="$(cd "$tmp2" && bash "$LIB" 2000-01-01)"
assert "revert_chains detected (revert of revert)" '[ "$(echo "$out2" | jq ".revert_chains|length")" -ge "1" ]'
rm -rf "$tmp2"

finish
