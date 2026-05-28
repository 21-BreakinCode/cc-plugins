---
description: "Review project KB entries — list active entries and mark stale ones as archived"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
---

# autoimprove-agents: Review KB

Review the knowledge base for the current project and manage entry lifecycle.

## Steps

1. Identify project name
2. List all entries in `~/.claude/autoimprove-agents/<project>/entries/`
3. Group by status: active | archived | historical
4. For each active entry, ask: "Is this still relevant?"
   - If a feature was archived/removed → update `status: archived`
   - If older than 90 days and no longer relevant → update `status: historical`
   - Otherwise keep as active
5. Show summary: "N active, N archived, N historical entries"
6. If `AUTOIMPROVE_NOTEBOOKLM_ENABLED=true`, sync status changes to NotebookLM

## Archiving

Update the frontmatter `status` field only. Never delete entries — history is preserved
but filtered from active queries.
