#!/usr/bin/env bash
# persist-principle-path.sh <key> <path>
#
# Persists a user-provided principle directory path to the cache.
# Called only after the orchestrator's guard prompt where the user picks
# "Provide path" — the path has already been validated.
#
# Usage:
#   persist-principle-path.sh "plaxieappier/foo" "/abs/path/to/dir"
#
# Cache file: $HOME/.claude/code-reviewer/principle-map.json
#   {
#     "version": 1,
#     "entries": { "<owner>/<repo>": "<abs path>", ... }
#   }
#
# Exits non-zero only on usage error; jq absence triggers a sed-based fallback.

set -euo pipefail

CACHE_FILE="${CODE_REVIEWER_CACHE_FILE:-${HOME}/.claude/code-reviewer/principle-map.json}"

key="${1:-}"
path="${2:-}"

if [[ -z "$key" || -z "$path" ]]; then
  echo "Usage: $(basename "$0") <owner/repo> <abs-path>" >&2
  exit 64
fi

[[ "$path" = /* ]] || { echo "Path must be absolute: $path" >&2; exit 64; }
[[ -d "$path" ]] || { echo "Path is not a directory: $path" >&2; exit 64; }

mkdir -p "$(dirname "$CACHE_FILE")"
# Seed schema if file missing OR empty (mktemp creates empty placeholder files).
[[ -s "$CACHE_FILE" ]] || echo '{"version":1,"entries":{}}' > "$CACHE_FILE"

if command -v jq &>/dev/null; then
  tmp=$(mktemp)
  jq --arg k "$key" --arg v "$path" \
     '.entries[$k] = $v' "$CACHE_FILE" > "$tmp"
  mv "$tmp" "$CACHE_FILE"
else
  # Minimal sed-fallback: rewrite the file in one shot. Only safe because
  # we control the schema; do not extend without jq.
  python3 - "$CACHE_FILE" "$key" "$path" <<'PY'
import json, sys
cache_file, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
with open(cache_file) as f:
    data = json.load(f)
data.setdefault("version", 1)
data.setdefault("entries", {})
data["entries"][k] = v
with open(cache_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
fi

echo "$CACHE_FILE"
