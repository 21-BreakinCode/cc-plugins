#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
SUT="$DIR/../scripts/migrate-to-okf.py"

B="$(mktemp -d)"
cat > "$B/07-red-flags.md" <<'EOF'
# Red flags

### Null deref on empty audio stream
- **What:** indexing streams[0] on a 0-byte upload crashes.
- **Evidence:** PR #812 (https://github.com/plaxieappier/video-center-2/pull/812) · commit a1b2c3d4e5f — 2026-03-01
- **Why it matters:** hard crash in the ingest path.
EOF
cat > "$B/02-pitfalls.md" <<'EOF'
# Pitfalls

### R1. Legacy checklist item without citation
- Some hand-written guidance with no evidence line.
EOF
cat > "$B/01-overview.md" <<'EOF'
---
repo: plaxieappier/testrepo
---
# Overview — testrepo
Hand-curated prose worth keeping.
EOF
touch "$B/.learn-state.json"

python3 "$SUT" "$B"

echo "Test: cited red-flag became a concept file"
assert "concept file exists" '[ -f "$B/red-flags/null-deref-on-empty-audio-stream.md" ]'

echo "Test: concept carries type + sources + verified"
assert "type present"     'grep -q "^type: RedFlag" "$B/red-flags/null-deref-on-empty-audio-stream.md"'
assert "pr source present" 'grep -q "pull/812" "$B/red-flags/null-deref-on-empty-audio-stream.md"'
assert "sha source present" 'grep -q "a1b2c3d4e5f" "$B/red-flags/null-deref-on-empty-audio-stream.md"'
assert "verified stamped"  'grep -q "human:whung" "$B/red-flags/null-deref-on-empty-audio-stream.md"'

echo "Test: uncited legacy block folded into index.md, not a concept"
assert "no pitfall concept" '[ -z "$(ls -A "$B/pitfalls" 2>/dev/null)" ] || ! ls "$B/pitfalls"/*.md >/dev/null 2>&1'
assert "legacy note in index" 'grep -q "Legacy checklist item" "$B/index.md"'
assert "curated prose in index" 'grep -q "Hand-curated prose worth keeping" "$B/index.md"'

echo "Test: reserved files + watermark present, old role files gone"
assert "index.md exists" '[ -f "$B/index.md" ]'
assert "log.md exists"   '[ -f "$B/log.md" ]'
assert "watermark kept"  '[ -f "$B/.learn-state.json" ]'
assert "old role file removed" '[ ! -f "$B/07-red-flags.md" ]'

rm -rf "$B"
finish
