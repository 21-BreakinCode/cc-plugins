#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
SUT="$DIR/../lib/load-principle.sh"

# Build a tiny bundle: one red-flag (stale, verified), one pitfall (fresh,
# machine-confirmed), one deprecated pitfall that must be skipped.
B="$(mktemp -d)"
mkdir -p "$B/red-flags" "$B/pitfalls"

cat > "$B/red-flags/old-blocker.md" <<'EOF'
---
type: RedFlag
title: old blocker
status: stable
stale_after: 2000-01-01
sources:
  - resource: https://example.com/pr/1
verified: [ { by: human:whung, at: 2026-08-07 } ]
---
**What:** an old red flag.
EOF

cat > "$B/pitfalls/fresh-pitfall.md" <<'EOF'
---
type: Pitfall
title: fresh pitfall
status: stable
stale_after: 2999-01-01
sources:
  - resource: https://example.com/pr/2
---
**What:** a fresh pitfall.
EOF

cat > "$B/pitfalls/gone.md" <<'EOF'
---
type: Pitfall
title: gone
status: deprecated
sources:
  - resource: https://example.com/pr/3
---
**What:** should be skipped.
EOF

cat > "$B/index.md" <<'EOF'
---
okf_version: "0.2"
---
# Overview — testrepo
Curated note lives here.
EOF

OUT="$(bash "$SUT" "$B")"

echo "Test: red-flag emitted before pitfall (priority order)"
assert "red-flag precedes pitfall" '[ "$(printf "%s" "$OUT" | grep -m1 -n "old blocker" | cut -d: -f1)" -lt "$(printf "%s" "$OUT" | grep -m1 -n "fresh pitfall" | cut -d: -f1)" ]'

echo "Test: stale entry flagged"
assert "old blocker marked STALE" 'printf "%s" "$OUT" | grep -q "old blocker \[STALE\]"'

echo "Test: trust tiers surfaced"
assert "red-flag human-reviewed" 'printf "%s" "$OUT" | grep -q "\[human-reviewed\]"'
assert "pitfall machine-confirmed" 'printf "%s" "$OUT" | grep -q "\[machine-confirmed\]"'

echo "Test: deprecated entry skipped"
assert "gone not emitted" '! printf "%s" "$OUT" | grep -q "should be skipped"'

echo "Test: index body emitted last"
assert "curated note present" 'printf "%s" "$OUT" | grep -q "Curated note lives here"'

echo "Test: footer reports skipped-deprecated"
assert "footer notes deprecated" 'printf "%s" "$OUT" | grep -qi "deprecated"'

rm -rf "$B"
finish
