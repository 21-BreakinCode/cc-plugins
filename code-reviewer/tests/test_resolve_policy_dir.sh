#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
SUT="$DIR/../lib/resolve-policy-dir.sh"

T="$(cd "$(mktemp -d)" && pwd -P)"
export GIT_CEILING_DIRECTORIES="$T"
git_q() { git -c user.email=t@t -c user.name=t -c protocol.file.allow=always "$@"; }

MAIN="$T/main clone"                       # space on purpose (Review Focus 2)
git_q init -q "$MAIN"
git_q -C "$MAIN" commit -q --allow-empty -m init
mkdir -p "$MAIN/.review-policy"
git_q -C "$MAIN" worktree add -q "$T/wt" -b wt

LIB="$T/lib"                                # submodule source (Review Focus 1)
git_q init -q "$LIB"
git_q -C "$LIB" commit -q --allow-empty -m init
git_q -C "$MAIN" submodule add -q "$LIB" sub
mkdir -p "$MAIN/sub/.review-policy"

mkdir -p "$T/abs-policy" "$T/home/x"

run() {  # <cwd> <env args...> ; sets OUT and RC
  local cwd="$1"; shift
  set +e
  OUT="$(cd "$cwd" && env "$@" bash "$SUT" 2>&1)"
  RC=$?
  set -e
}

echo "Test: env unset"
run "$MAIN" -u CODE_REVIEWER_POLICY_DIR
assert "unset exits 3" '[ "$RC" -eq 3 ]'
assert "unset says not set" 'printf "%s" "$OUT" | grep -q "not set"'

echo "Test: env empty"
run "$MAIN" CODE_REVIEWER_POLICY_DIR=
assert "empty exits 3" '[ "$RC" -eq 3 ]'

echo "Test: relative value in main clone"
run "$MAIN" CODE_REVIEWER_POLICY_DIR=.review-policy
assert "relative exits 0" '[ "$RC" -eq 0 ]'
assert "relative joins main root" '[ "$OUT" = "$MAIN/.review-policy" ]'

echo "Test: relative value from a linked worktree"
run "$T/wt" CODE_REVIEWER_POLICY_DIR=.review-policy
assert "worktree exits 0" '[ "$RC" -eq 0 ]'
assert "worktree resolves to main clone" '[ "$OUT" = "$MAIN/.review-policy" ]'

echo "Test: relative value inside a submodule"
run "$MAIN/sub" CODE_REVIEWER_POLICY_DIR=.review-policy
assert "submodule exits 0" '[ "$RC" -eq 0 ]'
assert "submodule resolves to its own root" '[ "$OUT" = "$MAIN/sub/.review-policy" ]'

echo "Test: ./ prefix and trailing slash"
run "$MAIN" CODE_REVIEWER_POLICY_DIR=./.review-policy
assert "./ prefix exits 0" '[ "$RC" -eq 0 ] && [ -d "$OUT" ]'
run "$MAIN" CODE_REVIEWER_POLICY_DIR=.review-policy/
assert "trailing slash exits 0" '[ "$RC" -eq 0 ] && [ -d "$OUT" ]'

echo "Test: absolute value"
run "$MAIN" CODE_REVIEWER_POLICY_DIR="$T/abs-policy"
assert "absolute unchanged" '[ "$RC" -eq 0 ] && [ "$OUT" = "$T/abs-policy" ]'

echo "Test: ~/ value"
run "$MAIN" HOME="$T/home" CODE_REVIEWER_POLICY_DIR='~/x'
assert "tilde expands to HOME" '[ "$RC" -eq 0 ] && [ "$OUT" = "$T/home/x" ]'

echo "Test: missing dir"
run "$MAIN" CODE_REVIEWER_POLICY_DIR=.nope
assert "missing exits 1" '[ "$RC" -eq 1 ]'
assert "missing names the path" 'printf "%s" "$OUT" | grep -q "no dir at $MAIN/.nope"'

echo "Test: outside a git repo"
run "$T/home" CODE_REVIEWER_POLICY_DIR=.review-policy
assert "not a repo exits 2" '[ "$RC" -eq 2 ]'

rm -rf "$T"
finish
