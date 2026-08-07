#!/usr/bin/env bash
# mine-pr-signals.sh <base> <since-date> [<until-date>] — merged-PR signals via gh.
# Offline test seam: CODE_REVIEWER_GH_FIXTURE_DIR → <dir>/pr-list.json, <dir>/pr-<N>.json
set -euo pipefail
base="${1:-}"; since="${2:-}"; until_date="${3:-}"
[[ -n "$base" && -n "$since" ]] || { echo "usage: mine-pr-signals.sh <base> <since> [until]" >&2; exit 64; }
command -v jq &>/dev/null || { echo "jq required: brew install jq" >&2; exit 2; }
fx="${CODE_REVIEWER_GH_FIXTURE_DIR:-}"

_pr_list() {
  if [[ -n "$fx" ]]; then cat "$fx/pr-list.json"; return; fi
  command -v gh &>/dev/null || { echo "gh required: https://cli.github.com" >&2; exit 2; }
  local q="merged:>=$since base:$base"; [[ -n "$until_date" ]] && q="$q merged:<=$until_date"
  gh pr list --state merged --search "$q" --limit 100 \
    --json number,title,mergedAt,mergeCommit
}
_pr_detail() {  # $1 = PR number → {number,reviews,files,comments}
  local n="$1"
  if [[ -n "$fx" ]]; then cat "$fx/pr-$n.json"; return; fi
  local slug pv inline
  slug="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  pv="$(gh pr view "$n" --json number,reviews,files)"
  inline="$(gh api "repos/$slug/pulls/$n/comments" \
    --jq '[.[]|{path, line:(.line // .original_line), body, url:.html_url, author:{login:.user.login}}]')"
  jq -n --argjson pv "$pv" --argjson c "$inline" '$pv + {comments:$c}'
}

_pr_list | jq -c '.[]' | while read -r pr; do
  n="$(echo "$pr" | jq -r '.number')"
  detail="$(_pr_detail "$n")"
  jq -n --argjson pr "$pr" --argjson d "$detail" '
    ($d.files // [] | map(.path)) as $paths
    | $pr + {
        reviews:  ($d.reviews  // [] | map({state, author:(.author.login // "?")})),
        comments: ($d.comments // [] | map({
          path, line, body, url, author:(.author.login // "?"),
          caused_change: ((.path as $path | $paths | index($path)) != null)
        }))
      }'
done | jq -s '.'
