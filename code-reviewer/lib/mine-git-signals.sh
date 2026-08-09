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

reverts=$(log_kv | awk -F'\t' 'tolower($2) ~ /^(revert|reapply)/ {print}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{sha:.[0],subject:.[1]})')

hotfixes=$(log_kv | awk -F'\t' 'tolower($2) ~ /(^|[^a-z])(fix|hotfix|bugfix)/ {print}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{sha:.[0],subject:.[1]})')

# churn: files by change frequency, excluding generated/vendored/lock files so
# hotspots reflect real bug-density, not doc-regeneration or dependency noise.
# Excluded if matched by CHURN_EXCLUDE_RE (universal generated/vendored/lock paths)
# OR marked `linguist-generated` in the repo's .gitattributes (repo-declared).
CHURN_EXCLUDE_RE='(^|/)(dist|build|vendor|node_modules|generated|out|coverage)/|(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|poetry\.lock|composer\.lock|Gemfile\.lock|go\.sum)$|\.min\.(js|css)$'

changed_files=$(git log "${range[@]}" --name-only --pretty=format: | sed '/^$/d')
generated_attr=$(printf '%s\n' "$changed_files" | sort -u \
  | git check-attr --stdin linguist-generated 2>/dev/null \
  | awk -F': ' '$NF=="set" || $NF=="true" {print $1}')

# read splits count+file so filenames with spaces survive (whole rest → file)
churn=$(printf '%s\n' "$changed_files" | sort | uniq -c | sort -rn \
  | while read -r count file; do
      if [[ "$file" =~ $CHURN_EXCLUDE_RE ]]; then continue; fi
      if [[ -n "$generated_attr" ]] && printf '%s\n' "$generated_attr" | grep -qxF -- "$file"; then continue; fi
      printf '%s\t%s\n' "$count" "$file"
    done \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{file:.[1],commits:(.[0]|tonumber)})')

# revert_chains: reverts whose target was itself reverted (misdiagnosis signal)
revert_chains='[]'
if [[ $(echo "$reverts" | jq 'length') -gt 0 ]]; then
  revert_chains=$(
    echo "$reverts" | jq -r '.[].sha' | while IFS= read -r sha; do
      target=$(git log -1 --pretty='%b' "$sha" 2>/dev/null \
        | grep -m1 -oE '[0-9a-f]{40}' || true)
      [[ -z "$target" ]] && continue
      if echo "$reverts" | jq -e --arg t "$target" 'map(.sha)|index($t)' >/dev/null 2>&1; then
        jq -n --arg s "$sha" --arg ss "$(git log -1 --pretty='%s' "$sha")" \
              --arg t "$target" --arg ts "$(git log -1 --pretty='%s' "$target" 2>/dev/null || echo '?')" \
          '{sha:$s, subject:$ss, target_sha:$t, target_subject:$ts}'
      fi
    done | jq -s '.'
  )
  [[ -z "$revert_chains" || "$revert_chains" == "null" ]] && revert_chains='[]'
fi

jq -n --argjson r "$reverts" --argjson h "$hotfixes" --argjson c "$churn" \
     --argjson rc "$revert_chains" \
  '{reverts:$r, hotfixes:$h, churn:$c, revert_chains:$rc}'
