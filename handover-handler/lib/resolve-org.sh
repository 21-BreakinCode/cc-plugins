#!/usr/bin/env bash
# resolve-org.sh — resolve the current org by inspecting initiation files
# under $LifeOS/01Project/. Tries git remote first, then workspace_root prefix.
# Prints the org name to stdout on success, exits 1 if nothing matches.
#
# Required env var: HH_LIFEOS_ROOT — see lib/lifeos-root.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! LIFEOS="$(bash "$SCRIPT_DIR/lifeos-root.sh")"; then
    exit 3
fi
PROJECT_ROOT="$LIFEOS/01Project"

cwd="$(pwd)"
remote_url=""
if remote_url_try=$(git -C "$cwd" remote get-url origin 2>/dev/null); then
    remote_url="$remote_url_try"
fi

# Phase 1: git remote → github_orgs match
if [ -n "$remote_url" ]; then
    for init in "$PROJECT_ROOT"/*/handover_handler__initiation.md; do
        [ -f "$init" ] || continue
        org_dir="$(basename "$(dirname "$init")")"
        gh_orgs_line=$(awk '/^github_orgs:/{
            sub(/^github_orgs:[[:space:]]*\[/, "")
            sub(/\][[:space:]]*$/, "")
            print
            exit
        }' "$init")
        [ -n "$gh_orgs_line" ] || continue
        IFS=',' read -ra gh_orgs <<< "$gh_orgs_line"
        for o in "${gh_orgs[@]}"; do
            o="${o## }"; o="${o%% }"
            o="${o//\"/}"; o="${o//\'/}"
            [ -n "$o" ] || continue
            if [[ "$remote_url" == *"/$o/"* ]] || [[ "$remote_url" == *":$o/"* ]]; then
                echo "$org_dir"
                exit 0
            fi
        done
    done
fi

# Phase 2: workspace_root prefix match
for init in "$PROJECT_ROOT"/*/handover_handler__initiation.md; do
    [ -f "$init" ] || continue
    org_dir="$(basename "$(dirname "$init")")"
    workspace=$(awk '/^workspace_root:/{
        sub(/^workspace_root:[[:space:]]*/, "")
        print
        exit
    }' "$init")
    [ -n "$workspace" ] || continue
    workspace="${workspace//\$HOME/$HOME}"
    if [ "$cwd" = "$workspace" ] || [[ "$cwd" == "$workspace"/* ]]; then
        echo "$org_dir"
        exit 0
    fi
done

# No match
exit 1
