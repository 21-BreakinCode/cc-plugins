---
description: "Push current session learnings to the project knowledge base"
allowed-tools: ["Read", "Write", "Bash", "Glob"]
---

# autoimprove-agents: Sync KB

Extract learnings from the current session and write them to the project KB.

## Steps

1. Identify the current project name (`basename` of git root or cwd)
2. Reflect on this conversation: what decisions, patterns, or bugs were relevant?
3. For each insight worth persisting, write a KB entry:
   - Call `bash ~/.claude/plugins/local/autoimprove-agents/lib/kb.sh` (source it)
   - Or write the file directly to `~/.claude/autoimprove-agents/<project>/entries/`
   - Use this frontmatter format:
     ```
     ---
     title: <concise title>
     date: YYYY-MM-DD
     status: active
     tags: [pattern|bug|decision|feature]
     project: <project>
     ---
     ```
4. If `AUTOIMPROVE_NOTEBOOKLM_ENABLED=true`, also push to NotebookLM (see `lib/notebooklm.sh`)
5. Report: "Synced N entries to project KB for [project]"

## What qualifies as a KB entry?
- Architectural decisions made
- Patterns established (naming, structure, approach)
- Non-obvious bugs fixed and how
- Features completed or archived
- Cross-cutting rules specific to this project
