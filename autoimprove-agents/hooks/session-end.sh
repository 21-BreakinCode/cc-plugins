#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

aa_ensure_dirs

INPUT="$(cat)"
PROJECT="$(aa_project_name)"
DATE="$(aa_date)"

# Load user config if present
CONFIG="${HOME}/.claude/autoimprove-agents/config.sh"
[ -f "$CONFIG" ] && source "$CONFIG"

# Write a pending self-improvement proposal file
# This surfaces during the Stop hook for user review
PROPOSAL_FILE="${AA_PROPOSALS_DIR}/${DATE}-${PROJECT}-$$.md"

cat > "$PROPOSAL_FILE" <<EOF
---
date: ${DATE}
project: ${PROJECT}
status: pending
type: reminder
---

## Session End — Pending Actions

**Project:** ${PROJECT}

Run these commands to capture session knowledge:

1. \`/autoimprove-agents:sync-kb\` — push session learnings to project KB
2. \`/autoimprove-agents:self-improve\` — review pending instruction improvement proposals

EOF

aa_log "Session ended for project: ${PROJECT}. Run /autoimprove-agents:sync-kb to capture learnings."
exit 0
