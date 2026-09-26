#!/usr/bin/env bash
# SessionStart: inject the Traditional Chinese writing rules.
# Gate A: only inside an Obsidian vault. Set OBSIDIAN_KIT_MANDARIN=0 to disable.
set -euo pipefail

[ "${OBSIDIAN_KIT_MANDARIN:-1}" = "0" ] && exit 0
[ -d "./.obsidian" ] || exit 0

[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
rules_file="${CLAUDE_PLUGIN_ROOT}/hooks/mandarin-rules.md"
[ -f "$rules_file" ] || exit 0

cat "$rules_file"
