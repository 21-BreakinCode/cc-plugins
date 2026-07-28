#!/usr/bin/env bash
# SessionStart hook — injects the adhd-review output style into the main session.
#
# On by default; set CLAUDE_ADHD_REVIEW=0 to disable it for a session. Fires for
# the MAIN session only — subagents do not run SessionStart hooks, so
# agent-to-agent hops stay full-detail by construction.
set -euo pipefail

# On by default; an explicit CLAUDE_ADHD_REVIEW=0 disables it for the session.
[ "${CLAUDE_ADHD_REVIEW:-1}" = "0" ] && exit 0

# Only proceed inside plugin execution, where Claude Code injects the root.
# Keeps the silent-no-op contract total: never abort under `set -u`.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
style_file="${CLAUDE_PLUGIN_ROOT}/output-styles/adhd-review.md"
[ -f "$style_file" ] || exit 0

# Emit the style body with its YAML frontmatter stripped (everything through the
# second `---`). SessionStart stdout is injected into the main session as context.
awk 'NR==1 && $0=="---"{in_fm=1; next} in_fm && $0=="---"{in_fm=0; next} !in_fm' "$style_file"
