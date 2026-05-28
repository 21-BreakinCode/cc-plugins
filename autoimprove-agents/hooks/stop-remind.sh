#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

aa_ensure_dirs

# Count pending proposals
PENDING_COUNT="$(ls "${AA_PROPOSALS_DIR}"/*.md 2>/dev/null | wc -l | tr -d ' ')"

if [ "$PENDING_COUNT" -gt 0 ]; then
  aa_log "${PENDING_COUNT} pending KB sync(s). Run /autoimprove-agents:sync-kb before closing."
fi

exit 0
