#!/usr/bin/env bash
# learn-state.sh — per-principle-dir learn watermark.
#   learn-state.sh read  <principle-dir>                 → JSON (empty if none)
#   learn-state.sh write <principle-dir> <merged_at> <sha> <counts-json> → path
set -euo pipefail
cmd="${1:-}"; dir="${2:-}"
die() { echo "$1" >&2; exit "${2:-1}"; }
[[ -n "$cmd" && -n "$dir" ]] || die "usage: learn-state.sh <read|write> <principle-dir> [...]" 64
command -v jq &>/dev/null || die "jq required: brew install jq" 2
state_file="$dir/.learn-state.json"

case "$cmd" in
  read)
    [[ -f "$state_file" ]] && cat "$state_file" || true
    ;;
  write)
    [[ -d "$dir" ]] || die "principle dir not found: $dir" 2
    merged_at="${3:-}"; sha="${4:-}"; counts="${5}"
    [[ -n "$counts" ]] || counts="{}"
    tmp="$(mktemp)"
    jq -n --arg at "$merged_at" --arg sha "$sha" --argjson counts "$counts" \
          --arg gen "$(date -u +%FT%TZ)" \
      '{version:1, last_merged_at:$at, last_merged_sha:$sha, counts:$counts, generated_at:$gen}' \
      > "$tmp"
    mv "$tmp" "$state_file"
    echo "$state_file"
    ;;
  *) die "unknown command: $cmd" 64 ;;
esac
