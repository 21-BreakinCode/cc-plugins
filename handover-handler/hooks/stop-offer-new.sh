#!/usr/bin/env bash
# stop-offer-new.sh — Claude Code Stop hook.
# When CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1, scans the recent transcript for a
# /hh:wrap-up run that completed, and emits a hookSpecificOutput.additionalContext
# message asking Claude to offer /hh:new via AskUserQuestion.
#
# Disabled by default. Set CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1 in ~/.zshrc to enable.
# Also gated on the per-repo convention: the cwd must have a working ./handover
# symlink (created by /hh:init-service). Without it, /hh:new can't run anyway.

set -euo pipefail

[ "${CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP:-0}" = "1" ] || exit 0

# Per-repo convention: ./handover must be a symlink that resolves into the vault.
# Matches /hh:new's Phase 1 precondition — no point offering /hh:new otherwise.
[ -L "./handover" ] && readlink -e "./handover" >/dev/null 2>&1 || exit 0

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

transcript_path=$(printf '%s' "$payload" | jq -r '.transcript_path // empty')
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

recent="$(tail -200 "$transcript_path" 2>/dev/null || true)"
[ -n "$recent" ] || exit 0

# Heuristic: user invoked /hh:wrap-up AND assistant printed "Wrap-up complete"
echo "$recent" | grep -q '/hh:wrap-up' || exit 0
echo "$recent" | grep -q 'Wrap-up complete' || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Reminder: /hh:wrap-up just ran. Ask the user via AskUserQuestion whether they'd like to start a new handover with /hh:new for any new threads of work surfaced by the wrap-up. Single question, two options: 'Yes — /hh:new <topic>' / 'No — done for today'."}}
JSON
