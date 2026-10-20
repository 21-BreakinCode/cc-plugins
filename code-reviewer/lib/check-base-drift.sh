#!/usr/bin/env bash
# check-base-drift.sh <repo-root> <latest-base-sha> <head-sha>
# Test-merges the PR head into the latest base with `git merge-tree --write-tree`.
# It writes git objects only: no ref, index, or working file changes.
# Prints one JSON object and exits 0:
#   {"status":"checked","base":..,"head":..,"merged_tree":..,"conflicts":[paths]}
#   {"status":"skipped","reason":".."}
set -euo pipefail
repo="${1:-}"; base="${2:-}"; head="${3:-}"
[[ -n "$repo" && -n "$head" ]] || { echo "usage: check-base-drift.sh <repo-root> <latest-base-sha> <head-sha>" >&2; exit 64; }
command -v jq &>/dev/null || { echo "jq required: brew install jq" >&2; exit 2; }

skip() { jq -n --arg reason "$1" '{status:"skipped", reason:$reason}'; exit 0; }

[[ -n "$base" ]] || skip "the latest base commit is unknown"
for sha in "$base" "$head"; do
  git -C "$repo" cat-file -e "$sha^{commit}" 2>/dev/null || skip "commit ${sha:0:7} is not in the local clone"
done

merge_stderr="$(mktemp)"
trap 'rm -f "$merge_stderr"' EXIT
set +e
merge_out="$(git -C "$repo" merge-tree --write-tree --name-only "$base" "$head" 2>"$merge_stderr")"
merge_rc=$?
set -e
# 0 = clean merge, 1 = conflicts. Anything else is a git failure.
(( merge_rc <= 1 )) || skip "git merge-tree failed: $(head -1 "$merge_stderr")"

# With conflicts, the conflicted paths follow the tree id, up to the first blank line.
conflicts=""
(( merge_rc == 0 )) || conflicts="$(sed -n '2,/^$/p' <<<"$merge_out" | sed '/^$/d')"

jq -n \
  --arg base "$(git -C "$repo" rev-parse "$base^{commit}")" \
  --arg head "$(git -C "$repo" rev-parse "$head^{commit}")" \
  --arg tree "$(head -1 <<<"$merge_out")" \
  --arg conflicts "$conflicts" \
  '{status:"checked", base:$base, head:$head, merged_tree:$tree,
    conflicts:($conflicts | split("\n") | map(select(length > 0)))}'
