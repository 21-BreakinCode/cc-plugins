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

# Skip when this style is already the active outputStyle: Claude Code then loads
# the same body natively, and a second copy only spends tokens. Precedence
# mirrors Claude Code's (project local > project shared > user); the first file
# that sets outputStyle wins.
# ponytail: ignores managed settings and --settings; add them if a user reports a miss.
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
for settings_file in "$project_dir/.claude/settings.local.json" \
                     "$project_dir/.claude/settings.json" \
                     "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"; do
  [ -f "$settings_file" ] || continue
  active_style=$(sed -n '/"outputStyle"/{s/.*"outputStyle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p;q;}' "$settings_file" 2>/dev/null || true)
  [ -n "$active_style" ] || continue
  case "$active_style" in
    "adhd-review:ADHD Review" | "ADHD Review") exit 0 ;;
  esac
  break
done

# Emit the style body with its YAML frontmatter stripped (everything through the
# second `---`). SessionStart stdout is injected into the main session as context.
awk 'NR==1 && $0=="---"{in_fm=1; next} in_fm && $0=="---"{in_fm=0; next} !in_fm' "$style_file"
