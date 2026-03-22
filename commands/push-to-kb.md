---
description: "Push a finalized Obsidian note to the project NotebookLM KB (requires autoimprove-agents)"
allowed-tools: ["Read", "Bash"]
---

# zettelkasten-capture: Push to KB

Push a finalized Obsidian note to the project knowledge base.

## Steps

1. Read the note file path (passed as argument, or ask if not provided)
2. Check `AUTOIMPROVE_NOTEBOOKLM_ENABLED`:
   - If `false`: write to local file KB via `~/.claude/plugins/local/autoimprove-agents/lib/kb.sh`
   - If `true`: also push to NotebookLM via `~/.claude/plugins/local/autoimprove-agents/lib/notebooklm.sh`
3. Extract project name from cwd or frontmatter
4. Write entry with `status: active`, tags from note frontmatter
5. Confirm: "Note pushed to KB for project: [project]"

## Dependency

Requires `autoimprove-agents` plugin to be installed.
If not installed, outputs a warning and skips.
