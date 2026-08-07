#!/usr/bin/env bash
# mine-git-signals.sh <since> [<until>] — deterministic commit signals.
#   <since> may be a git rev (uses <since>..<until>) or a date (uses --since).
# stdout JSON: {reverts, hotfixes, churn}
set -euo pipefail
since="${1:-}"; until_ref="${2:-HEAD}"
[[ -n "$since" ]] || { echo "usage: mine-git-signals.sh <since> [until]" >&2; exit 64; }
command -v jq &>/dev/null || { echo "jq required: brew install jq" >&2; exit 2; }
git rev-parse --git-dir &>/dev/null || { echo "not a git repo" >&2; exit 2; }

if git rev-parse --verify --quiet "${since}^{commit}" >/dev/null 2>&1; then
  range=("${since}..${until_ref}")
else
  range=("--since=${since}")
fi

log_kv() { git log "${range[@]}" --pretty='%H%x09%s'; }

reverts=$(log_kv | awk -F'\t' 'tolower($2) ~ /^revert/ {print}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{sha:.[0],subject:.[1]})')

hotfixes=$(log_kv | awk -F'\t' 'tolower($2) ~ /(^|[^a-z])(fix|hotfix|bugfix)/ {print}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{sha:.[0],subject:.[1]})')

churn=$(git log "${range[@]}" --name-only --pretty=format: \
  | sed '/^$/d' | sort | uniq -c | sort -rn \
  | awk '{printf "%s\t%s\n",$1,$2}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{file:.[1],commits:(.[0]|tonumber)})')

jq -n --argjson r "$reverts" --argjson h "$hotfixes" --argjson c "$churn" \
  '{reverts:$r, hotfixes:$h, churn:$c}'
