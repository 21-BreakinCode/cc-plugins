#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
SUT="$DIR/../lib/check-base-drift.sh"

T="$(cd "$(mktemp -d)" && pwd -P)"
export GIT_CEILING_DIRECTORIES="$T"
git_q() { git -c user.email=t@t -c user.name=t "$@"; }
commit_all() { git_q -C "$REPO" add -A && git_q -C "$REPO" commit -q -m "$1"; }

# main: a helper and a shared file. pr: renames the helper and edits the shared file.
# main then moves on: it edits the shared file too (a conflict) and adds a new caller
# of the old helper name (a clean merge that breaks at run time).
REPO="$T/repo"
git_q init -q -b main "$REPO"
printf 'def old_helper(value):\n    return value * 2\n' > "$REPO/app.py"
printf 'shared line\n' > "$REPO/shared.txt"
commit_all base
git_q -C "$REPO" switch -q -c pr
printf 'def double(value):\n    return value * 2\n' > "$REPO/app.py"
printf 'pr line\n' > "$REPO/shared.txt"
commit_all pr
HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
git_q -C "$REPO" switch -q main
printf 'from app import old_helper\n\nprint(old_helper(3))\n' > "$REPO/caller.py"
commit_all "clean caller"
CLEAN_BASE="$(git -C "$REPO" rev-parse HEAD)"
printf 'main line\n' > "$REPO/shared.txt"
commit_all "conflicting edit"
CONFLICT_BASE="$(git -C "$REPO" rev-parse HEAD)"
REPO_STATE_BEFORE="$(git -C "$REPO" for-each-ref; git -C "$REPO" status --porcelain)"

echo "Test: conflicting merge"
out="$(bash "$SUT" "$REPO" "$CONFLICT_BASE" "$HEAD_SHA")"
assert "status checked" '[ "$(jq -r .status <<<"$out")" = "checked" ]'
assert "lists the conflicted file" '[ "$(jq -c .conflicts <<<"$out")" = "[\"shared.txt\"]" ]'
assert "merged tree is an object id" '[[ "$(jq -r .merged_tree <<<"$out")" =~ ^[0-9a-f]{40}$ ]]'
assert "base and head are full shas" '[ "$(jq -r .base <<<"$out")" = "$CONFLICT_BASE" ] && [ "$(jq -r .head <<<"$out")" = "$HEAD_SHA" ]'
TREE="$(jq -r .merged_tree <<<"$out")"
assert "merged tree keeps the base's new caller of the removed helper" \
  'git -C "$REPO" grep -q -w old_helper "$TREE" -- caller.py'
assert "the PR head has no such caller" '! git -C "$REPO" grep -q -w old_helper "$HEAD_SHA"'
assert "no ref, index, or file changed" '[ "$(git -C "$REPO" for-each-ref; git -C "$REPO" status --porcelain)" = "$REPO_STATE_BEFORE" ]'

echo "Test: clean merge"
out="$(bash "$SUT" "$REPO" "$CLEAN_BASE" "$HEAD_SHA")"
assert "clean merge has no conflicts" '[ "$(jq -c .conflicts <<<"$out")" = "[]" ]'
assert "clean merge status checked" '[ "$(jq -r .status <<<"$out")" = "checked" ]'

echo "Test: skipped"
out="$(bash "$SUT" "$REPO" "" "$HEAD_SHA")"
assert "empty base is skipped" '[ "$(jq -r .status <<<"$out")" = "skipped" ] && jq -r .reason <<<"$out" | grep -q unknown'
out="$(bash "$SUT" "$REPO" 1111111111111111111111111111111111111111 "$HEAD_SHA")"
assert "missing commit is skipped with a reason" 'jq -r .reason <<<"$out" | grep -q "1111111 is not in the local clone"'

echo "Test: usage"
set +e; bash "$SUT" >/dev/null 2>&1; rc=$?; set -e
assert "no arguments exits 64" '[ "$rc" -eq 64 ]'

finish
