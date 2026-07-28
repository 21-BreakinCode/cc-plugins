#!/usr/bin/env bash
# receipts-check.sh — Stop hook entry.
#
# Cheap env guards live here in bash so the default-OFF path is a ~3-line no-op
# that never spawns python. Real work is delegated to lib/check.py.
set -euo pipefail

# Don't recurse into our own headless judge call (judge.sh sets RECEIPTS_NESTED=1).
[ "${RECEIPTS_NESTED:-0}" = "1" ] && exit 0

# Opt-in: a blocking hook must be off by default.
[ "${CLAUDE_RECEIPTS:-0}" = "1" ] || exit 0

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"

# Fail open: any error in the checker must never wedge the session.
cat | python3 "${lib_dir}/check.py" || exit 0
