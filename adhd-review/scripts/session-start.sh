#!/usr/bin/env bash
# SessionStart hook — injects the adhd-review reply rules into the main session.
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
rules_file="${CLAUDE_PLUGIN_ROOT}/scripts/session-rules.md"
[ -f "$rules_file" ] || exit 0

# SessionStart stdout is injected into the main session as context.
cat "$rules_file"
