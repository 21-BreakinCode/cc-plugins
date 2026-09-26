#!/usr/bin/env bash
# PostToolUse(Write|Edit): after Claude edits an Excalidraw drawing (.md with excalidraw-plugin frontmatter), run the
# obsidian-kit geometry lint and send errors back to Claude (exit 2).
# Never writes files. If Obsidian is closed the lint cannot run, so it only reminds.
set -uo pipefail

payload=$(cat)
file=$(printf '%s' "$payload" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).tool_input.file_path||"")}catch{}})' || true)

case "$file" in
  *.md) ;;
  *) exit 0 ;;
esac
case "$file" in
  */Credentials/*) exit 0 ;;
esac
[ -f "$file" ] || exit 0
# Any .md with the Excalidraw frontmatter key is a drawing, e.g. "Map.flowchart.md".
head -n 5 "$file" | grep -q '^excalidraw-plugin:' || exit 0

vault_root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$vault_root/.obsidian" ] || exit 0
vault_relative_path="${file#"$vault_root"/}"
lint_script="${CLAUDE_PLUGIN_ROOT}/scripts/excalidraw/lint.py"

lint_output=$(python3 "$lint_script" "$vault_relative_path" 2>&1)
lint_status=$?

if [ "$lint_status" -eq 2 ]; then
  {
    echo "excalidraw-lint flagged $vault_relative_path. Use /obsidian-kit:update-excali to fix:"
    printf '%s\n' "$lint_output" | grep '^ERROR'
  } >&2
  exit 2
fi

if [ "$lint_status" -ne 0 ]; then
  reminder="excalidraw-lint could not run (is Obsidian open?). Use /obsidian-kit:update-excali to lint and render $vault_relative_path."
else
  reminder="Drawing $vault_relative_path passed geometry lint. Per /obsidian-kit:update-excali, render it and score it with references/excali-rubric.md before finishing."
fi
node -e 'process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:process.argv[1]}}))' "$reminder"
exit 0
