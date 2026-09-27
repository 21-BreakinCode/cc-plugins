#!/usr/bin/env bash
# resolve-policy-dir.sh — print the absolute repo review-policy dir.
#
# Reads CODE_REVIEWER_POLICY_DIR. A relative value resolves against the main
# clone root, so a linked worktree shares its main clone's policy. A leading
# "~/" expands to $HOME, because settings.json env values arrive literally.
#
# Exit: 0 found (stdout = abs path) | 1 no dir | 2 not a git repo | 3 env unset
set -euo pipefail

policy_value="${CODE_REVIEWER_POLICY_DIR:-}"
if [[ -z "$policy_value" ]]; then
  echo "policy: off (CODE_REVIEWER_POLICY_DIR not set). Start the session in the main clone, or symlink .claude/settings.local.json to ~/.claude/settings.appier-cs.json." >&2
  exit 3
fi

common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
  echo "policy: off (not a git repo)" >&2
  exit 2
}
# A submodule's common dir is <super>/.git/modules/<name>; use its own top level.
if [[ "$(basename "$common_dir")" == ".git" ]]; then
  main_root="$(dirname "$common_dir")"
else
  main_root="$(git rev-parse --show-toplevel)"
fi

case "$policy_value" in
  "~/"*) policy_dir="$HOME/${policy_value#\~/}" ;;
  /*)    policy_dir="$policy_value" ;;
  *)     policy_dir="$main_root/$policy_value" ;;
esac
policy_dir="${policy_dir%/}"

if [[ ! -d "$policy_dir" ]]; then
  echo "policy: off (no dir at $policy_dir)" >&2
  exit 1
fi
echo "$policy_dir"
