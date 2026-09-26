#!/usr/bin/env bash
# offer-handover.sh — Claude Code Stop hook.
# When OBSIDIAN_KIT_OFFER_HANDOVER=1, scans the recent transcript for a
# /obsidian-kit:handover-wrap-up run that completed, and emits a
# hookSpecificOutput.additionalContext message asking Claude to offer
# /obsidian-kit:handover-new via AskUserQuestion.
#
# Disabled by default. Set OBSIDIAN_KIT_OFFER_HANDOVER=1 in ~/.zshrc to enable.
# Also gated on the per-repo convention: the cwd must have a working ./handover
# symlink (created by /obsidian-kit:handover-init-service). Without it,
# /obsidian-kit:handover-new can't run anyway.

set -euo pipefail

[ "${OBSIDIAN_KIT_OFFER_HANDOVER:-0}" = "1" ] || exit 0

# Per-repo convention: ./handover must be a symlink that resolves into the vault.
# Matches /obsidian-kit:handover-new's Phase 1 precondition — no point offering
# /obsidian-kit:handover-new otherwise.
[ -L "./handover" ] && readlink -e "./handover" >/dev/null 2>&1 || exit 0

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

transcript_path=$(printf '%s' "$payload" | jq -r '.transcript_path // empty')
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

recent="$(tail -200 "$transcript_path" 2>/dev/null || true)"
[ -n "$recent" ] || exit 0

# Heuristic: user invoked /obsidian-kit:handover-wrap-up AND assistant printed "Wrap-up complete"
echo "$recent" | grep -q '/obsidian-kit:handover-wrap-up' || exit 0
echo "$recent" | grep -q 'Wrap-up complete' || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Reminder: /obsidian-kit:handover-wrap-up just ran. Ask the user via AskUserQuestion whether they'd like to start a new handover with /obsidian-kit:handover-new for any new threads of work surfaced by the wrap-up. Single question, two options: 'Yes — /obsidian-kit:handover-new <topic>' / 'No — done for today'."}}
JSON
