#!/usr/bin/env bash
# check-diff-coverage.sh coverage <pr>
# check-diff-coverage.sh validate <pr> <findings-json-file>
# Offline seam: CODE_REVIEWER_GH_FIXTURE_DIR → <dir>/diff-<pr>.txt
set -euo pipefail
mode="${1:-}"; pr="${2:-}"
[[ -n "$mode" && -n "$pr" ]] || { echo "usage: check-diff-coverage.sh <coverage|validate> <pr> [findings.json]" >&2; exit 64; }
command -v jq &>/dev/null || { echo "jq required: brew install jq" >&2; exit 2; }
fx="${CODE_REVIEWER_GH_FIXTURE_DIR:-}"

_diff() {
  if [[ -n "$fx" ]]; then cat "$fx/diff-$pr.txt"; return; fi
  command -v gh &>/dev/null || { echo "gh required: https://cli.github.com" >&2; exit 2; }
  gh pr diff "$pr"
}

EXCLUDE_RE='(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|\.min\.(js|css)$|\.(png|jpe?g|gif|svg|pdf|lock)$)'

# ponytail: line check is file-presence only; upgrade = parse @@ hunk ranges.
changed="$(_diff | sed -n 's#^+++ b/##p')"

case "$mode" in
  coverage)
    printf '%s\n' "$changed" | jq -R -s --arg re "$EXCLUDE_RE" '
      split("\n") | map(select(length>0)) | map(
        if test($re) then {path:., covered:false, exclude_reason:"generated/binary/lock"}
        else {path:., covered:true} end) as $files
      | {files:$files, uncovered:[$files[]|select(.covered==false)|.path]}'
    ;;
  validate)
    findings="${3:-}"; [[ -f "$findings" ]] || { echo "findings json file required" >&2; exit 64; }
    printf '%s\n' "$changed" | jq -R -s --slurpfile f "$findings" '
      (split("\n")|map(select(length>0))) as $c
      | $f[0] | map(. + {location_verified: ((.file as $file | $c | index($file)) != null)})
      | map(if .location_verified then . else . + {flag:"unverified location"} end)'
    ;;
  *) echo "unknown mode: $mode" >&2; exit 64 ;;
esac
