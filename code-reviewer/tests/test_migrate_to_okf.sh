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
- **Trigger:** guard against concurrent writes

### Bug: race condition in ingest
- **What:** two workers claim the same
  job when the queue is drained concurrently.
- **Evidence:** PR #900 (https://github.com/plaxieappier/video-center-2/pull/900)
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
cat > "$B/04-domain-traps.md" <<'EOF'
Orphan prose with no heading here.
EOF
cat > "$B/05-hotspots.md" <<'EOF'
# Hotspots

Evidence-anchored entries mined from merged git+PR history.
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

echo "Test: colon-in-title is YAML-quoted"
assert "quoted title" 'grep -q '"'"'title: "Bug: race condition in ingest"'"'"' "$B/red-flags/bug-race-condition-in-ingest.md"'

echo "Test: wrapped What continuation line is captured, not truncated"
assert "continuation text present" 'grep -q "job when the queue is drained concurrently" "$B/red-flags/bug-race-condition-in-ingest.md"'

echo "Test: cited block's extra bullet (beyond What/Evidence/Why) is preserved as Notes"
assert "Notes section present" 'grep -q "\*\*Notes:\*\*" "$B/red-flags/null-deref-on-empty-audio-stream.md"'
assert "extra bullet text present" 'grep -q "guard against concurrent writes" "$B/red-flags/null-deref-on-empty-audio-stream.md"'

echo "Test: uncited legacy block folded into index.md, not a concept"
assert "no pitfall concept" '[ -z "$(ls -A "$B/pitfalls" 2>/dev/null)" ] || ! ls "$B/pitfalls"/*.md >/dev/null 2>&1'
assert "legacy note in index" 'grep -q "Legacy checklist item" "$B/index.md"'
assert "curated prose in index" 'grep -q "Hand-curated prose worth keeping" "$B/index.md"'

echo "Test: non-### preamble in a headingless role file is folded into index.md"
assert "orphan prose in index" 'grep -q "Orphan prose with no heading here" "$B/index.md"'
assert "no domain-trap concept" '[ -z "$(ls -A "$B/domain-traps" 2>/dev/null)" ] || ! ls "$B/domain-traps"/*.md >/dev/null 2>&1'

echo "Test: pure seed boilerplate (no real content) is not folded into index.md"
assert "seed sentence absent from index" '! grep -q "Evidence-anchored entries mined from merged git+PR history" "$B/index.md"'
assert "no hotspots concept" '[ -z "$(ls -A "$B/hotspots" 2>/dev/null)" ] || ! ls "$B/hotspots"/*.md >/dev/null 2>&1'

echo "Test: reserved files + watermark present, old role files gone"
assert "index.md exists" '[ -f "$B/index.md" ]'
assert "log.md exists"   '[ -f "$B/log.md" ]'
assert "watermark kept"  '[ -f "$B/.learn-state.json" ]'
assert "old role file removed" '[ ! -f "$B/07-red-flags.md" ]'

rm -rf "$B"
finish
