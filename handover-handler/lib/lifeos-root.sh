#!/usr/bin/env bash
# lifeos-root.sh — resolve the LifeOS vault root. Single source of truth for
# every command and lib in this plugin.
#
# Required env var: HH_LIFEOS_ROOT — absolute path to the LifeOS vault.
# There is deliberately NO default. A wrong-but-plausible fallback path fails
# far from the cause (a missing initiation.md, an unreachable org) and sends
# the user debugging the wrong thing.
#
# Prints the resolved root to stdout on success.
# Exit codes:
#   0 — resolved, vault looks valid
#   3 — not configured or not a valid vault (setup guidance written to stderr)

set -euo pipefail

setup_guidance() {
    cat >&2 <<EOF

  How to fix — point hh at your LifeOS vault:

    1. Find it. It is the folder containing '01Project/':
         find "\$HOME" -maxdepth 4 -type d -name '01Project' 2>/dev/null

    2. Export the parent of that folder in your shell profile (~/.zshrc):
         export HH_LIFEOS_ROOT="\$HOME/Projects/LifeOS"

    3. Reload, then re-run this command:
         source ~/.zshrc

  Quote the value if the path contains spaces (an iCloud-synced vault does).

EOF
}

if [ -z "${HH_LIFEOS_ROOT:-}" ]; then
    echo "hh: HH_LIFEOS_ROOT is not set — cannot locate your LifeOS vault." >&2
    setup_guidance
    exit 3
fi

if [ ! -d "$HH_LIFEOS_ROOT" ]; then
    echo "hh: HH_LIFEOS_ROOT points at a path that does not exist:" >&2
    echo "      $HH_LIFEOS_ROOT" >&2
    echo "    If the vault is cloud-synced, confirm it has finished downloading." >&2
    setup_guidance
    exit 3
fi

if [ ! -d "$HH_LIFEOS_ROOT/01Project" ]; then
    echo "hh: HH_LIFEOS_ROOT exists but has no '01Project/' subfolder:" >&2
    echo "      $HH_LIFEOS_ROOT" >&2
    echo "    This does not look like a LifeOS vault root." >&2
    setup_guidance
    exit 3
fi

echo "$HH_LIFEOS_ROOT"
