#!/usr/bin/env bash
# load-principle.sh <principle-dir> [cap-chars]
#
# Concatenates principle .md files in priority order so the most
# merge-blocking content appears first within the character budget.
#
# Priority order (highest first):
#   07-red-flags  → patterns that should block merge
#   02-pitfalls   → recurring bug clusters
#   05-hotspots   → high-bug-density files
#   04-domain-traps
#   03-review-patterns
#   06-conventions
#   01-overview
#
# Soft cap defaults to 30000 characters. Files added until the next file
# would exceed the cap; remainder are listed under "Truncated".
#
# stdout: concatenated content with file headers + a coverage footer.

set -euo pipefail

dir="${1:-}"
cap="${2:-30000}"

[[ -n "$dir" && -d "$dir" ]] || {
  echo "Usage: $(basename "$0") <principle-dir> [cap-chars]" >&2
  exit 64
}

priority=(
  "07-red-flags.md"
  "02-pitfalls.md"
  "05-hotspots.md"
  "04-domain-traps.md"
  "03-review-patterns.md"
  "06-conventions.md"
  "01-overview.md"
)

included=()
truncated=()
total=0

for f in "${priority[@]}"; do
  fp="$dir/$f"
  [[ -f "$fp" ]] || continue
  size=$(wc -c < "$fp" | tr -d ' ')
  if (( total + size > cap )); then
    truncated+=("$f")
    continue
  fi
  included+=("$f")
  total=$((total + size))
done

# Emit included files with headers
for f in "${included[@]}"; do
  printf '=== %s ===\n' "$f"
  cat "$dir/$f"
  printf '\n'
done

# Footer: coverage report
printf '=== Principle Coverage ===\n'
printf 'Source dir: %s\n' "$dir"
printf 'Included (%d): %s\n' "${#included[@]}" "${included[*]:-none}"
if (( ${#truncated[@]} > 0 )); then
  printf 'Truncated for context budget (%d): %s\n' "${#truncated[@]}" "${truncated[*]}"
fi
printf 'Total chars: %d / cap %d\n' "$total" "$cap"
