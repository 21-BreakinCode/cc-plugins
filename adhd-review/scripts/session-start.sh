#!/usr/bin/env bash
# SessionStart hook — always-on mode for the adhd-review output style.
#
# Opt-in via a flag file; completely inert without it, so installing the plugin
# alone changes nothing. Fires for the MAIN session only — subagents do not run
# SessionStart hooks, so agent-to-agent hops stay full-detail by construction.
set -euo pipefail

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -f "$config_dir/.adhd-review-always" ] || exit 0   # no flag → do nothing, silently

# Only proceed inside plugin execution, where Claude Code injects the root.
# Keeps the silent-no-op contract total: never abort under `set -u`.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
style_file="${CLAUDE_PLUGIN_ROOT}/output-styles/adhd-review.md"
[ -f "$style_file" ] || exit 0

# Emit the style body with its YAML frontmatter stripped (everything through the
# second `---`). SessionStart stdout is injected into the main session as context.
awk 'NR==1 && $0=="---"{in_fm=1; next} in_fm && $0=="---"{in_fm=0; next} !in_fm' "$style_file"
