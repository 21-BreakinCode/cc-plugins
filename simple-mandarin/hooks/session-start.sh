#!/usr/bin/env bash
# SessionStart hook. It injects the simple-mandarin rules into the main session.
#
# On by default. Set CLAUDE_SIMPLE_MANDARIN=0 to disable it for a session. This
# fires for the MAIN session only. Subagents do not run SessionStart hooks, so
# agent-to-agent hops stay unaffected.
set -euo pipefail

[ "${CLAUDE_SIMPLE_MANDARIN:-1}" = "0" ] && exit 0

[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
rules_file="${CLAUDE_PLUGIN_ROOT}/hooks/session-rules.md"
[ -f "$rules_file" ] || exit 0

cat "$rules_file"
