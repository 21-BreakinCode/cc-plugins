#!/usr/bin/env bash
# SessionStart hook. It injects the simple-mandarin output style into the main session.
#
# On by default. Set CLAUDE_SIMPLE_MANDARIN=0 to disable it for a session. This
# fires for the MAIN session only. Subagents do not run SessionStart hooks, so
# agent-to-agent hops stay unaffected.
set -euo pipefail

[ "${CLAUDE_SIMPLE_MANDARIN:-1}" = "0" ] && exit 0

[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
style_file="${CLAUDE_PLUGIN_ROOT}/output-styles/simple-mandarin.md"
[ -f "$style_file" ] || exit 0

awk 'NR==1 && $0=="---"{in_fm=1; next} in_fm && $0=="---"{in_fm=0; next} !in_fm' "$style_file"
