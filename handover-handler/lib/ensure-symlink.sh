#!/usr/bin/env bash
# ensure-symlink.sh — idempotently create a symlink at <link_path> pointing
# to <target>. Refuses to destroy data: if a non-empty directory or regular
# file exists at <link_path>, exits non-zero and reports.
#
# Usage: ensure-symlink.sh <link_path> <target> [force]
# Exit codes:
#   0 — created, or already correct, or empty-dir replaced
#   1 — blocked by existing content (non-empty dir or regular file)
#   3 — target does not exist
#   4 — symlink exists pointing elsewhere, and "force" was not specified

set -euo pipefail

link_path="${1:?usage: ensure-symlink.sh <link_path> <target> [force]}"
target="${2:?usage: ensure-symlink.sh <link_path> <target> [force]}"
mode="${3:-noforce}"

if [ ! -e "$target" ]; then
    echo "ensure-symlink.sh: target does not exist: $target" >&2
    exit 3
fi

if [ ! -e "$link_path" ] && [ ! -L "$link_path" ]; then
    ln -s "$target" "$link_path"
    echo "ensure-symlink.sh: created $link_path -> $target" >&2
    exit 0
fi

if [ -L "$link_path" ]; then
    current="$(readlink "$link_path")"
    if [ "$current" = "$target" ]; then
        echo "ensure-symlink.sh: already correct $link_path -> $target" >&2
        exit 0
    fi
    if [ "$mode" = "force" ]; then
        ln -sfn "$target" "$link_path"
        echo "ensure-symlink.sh: replaced $link_path -> $target (was: $current)" >&2
        exit 0
    fi
    echo "ensure-symlink.sh: $link_path -> $current (wanted: $target). Pass 'force' to overwrite." >&2
    exit 4
fi

if [ -d "$link_path" ]; then
    if [ -z "$(ls -A "$link_path" 2>/dev/null)" ]; then
        rmdir "$link_path"
        ln -s "$target" "$link_path"
        echo "ensure-symlink.sh: replaced empty dir $link_path -> $target" >&2
        exit 0
    fi
    echo "ensure-symlink.sh: directory exists with content: $link_path (move contents manually)" >&2
    exit 1
fi

echo "ensure-symlink.sh: regular file in the way: $link_path" >&2
exit 1
