#!/usr/bin/env bash
# load-principle.sh <bundle-dir> [cap-chars]
#
# Walk an OKF v0.2 bundle in review-priority order and emit its concepts,
# most merge-blocking first, within a character budget. Skips deprecated
# concepts; flags stale ones; surfaces each concept's trust tier.
#
# Priority = role-dir order: red-flags, pitfalls, hotspots, domain-traps,
# review-patterns, conventions; then index.md body last.
set -euo pipefail

dir="${1:-}"
cap="${2:-30000}"
[[ -n "$dir" && -d "$dir" ]] || {
  echo "Usage: $(basename "$0") <bundle-dir> [cap-chars]" >&2
  exit 64
}

today="$(date +%F)"
role_dirs=(red-flags pitfalls hotspots domain-traps review-patterns conventions)

included=(); stale_list=(); truncated=(); skipped_dep=(); skipped_malformed=(); total=0

_fm() {  # extract frontmatter block of <file>
  awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$1"
}

_emit() {  # <file> ; returns 1 if skipped/truncated
  local f="$1" fm status stale title type tier flag="" chunk size
  fm="$(_fm "$f")"
  status="$(printf '%s\n' "$fm" | sed -n 's/^status:[[:space:]]*//p' | head -1)"
  status="${status:-stable}"
  [[ "$status" == "deprecated" ]] && { skipped_dep+=("$(basename "$f")"); return 1; }
  printf '%s\n' "$fm" | grep -qE 'resource:[[:space:]]*[^[:space:]]' || { skipped_malformed+=("$(basename "$f")"); return 1; }
  stale="$(printf '%s\n' "$fm" | sed -n 's/^stale_after:[[:space:]]*//p' | head -1)"
  title="$(printf '%s\n' "$fm" | sed -n 's/^title:[[:space:]]*//p' | head -1)"
  type="$(printf '%s\n' "$fm" | sed -n 's/^type:[[:space:]]*//p' | head -1)"
  if printf '%s\n' "$fm" | grep -q '^verified:'; then tier="human-reviewed"; else tier="machine-confirmed"; fi
  if [[ -n "$stale" && "$stale" < "$today" ]]; then flag=" [STALE]"; stale_list+=("$(basename "$f")"); fi
  chunk="=== ${type}: ${title}${flag} [${tier}] ===
$(cat "$f")
"
  size=${#chunk}
  if (( total + size > cap )); then truncated+=("$(basename "$f")"); return 1; fi
  printf '%s\n' "$chunk"
  included+=("$(basename "$f")"); total=$((total + size))
}

for rd in "${role_dirs[@]}"; do
  [[ -d "$dir/$rd" ]] || continue
  for f in "$dir/$rd"/*.md; do
    [[ -e "$f" ]] || continue
    [[ -r "$f" ]] || { printf 'warn: unreadable %s\n' "$f" >&2; continue; }
    _emit "$f" || true
  done
done

# index.md body last (lowest priority), within cap
if [[ -f "$dir/index.md" ]]; then
  body="$(awk 'c>=2{print} /^---/{c++}' "$dir/index.md")"
  [[ "$(awk 'NR==1' "$dir/index.md")" == "---" ]] || body="$(cat "$dir/index.md")"
  chunk="=== index.md ===
${body}
"
  if (( total + ${#chunk} <= cap )); then
    printf '%s\n' "$chunk"; included+=("index.md"); total=$((total + ${#chunk}))
  else
    truncated+=("index.md")
  fi
fi

printf '=== Principle Coverage ===\n'
printf 'Source dir: %s\n' "$dir"
printf 'Included (%d): %s\n' "${#included[@]}" "${included[*]:-none}"
(( ${#stale_list[@]} > 0 )) && printf 'Stale-flagged (%d): %s\n' "${#stale_list[@]}" "${stale_list[*]}"
(( ${#skipped_dep[@]} > 0 )) && printf 'Skipped deprecated (%d): %s\n' "${#skipped_dep[@]}" "${skipped_dep[*]}"
(( ${#skipped_malformed[@]} > 0 )) && printf 'Skipped (no sources) (%d): %s\n' "${#skipped_malformed[@]}" "${skipped_malformed[*]}"
(( ${#truncated[@]} > 0 )) && printf 'Truncated for context budget (%d): %s\n' "${#truncated[@]}" "${truncated[*]}"
printf 'Total chars: %d / cap %d\n' "$total" "$cap"
