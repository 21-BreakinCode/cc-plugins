---
description: "Review and apply self-improvement proposals for agent instruction files"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
---

# autoimprove-agents: Self-Improve

Review proposed improvements to agent instruction files and apply approved ones.

## Process

### Mode A — Refine instructions

1. Read the current project's `.claude/agents/project-kb.md`
2. Read recent KB entries in `~/.claude/autoimprove-agents/<project>/entries/`
3. Identify patterns: are there recurring topics not covered in the agent instructions?
4. Generate a unified diff of proposed changes to the agent file
5. **Show diff to user and ask for approval before applying**
6. On approval: apply the diff with Edit tool
7. On rejection: discard and note why

### Mode B — Knowledge already accumulated

KB entries written via `/autoimprove-agents:sync-kb` are Mode B.
No additional action needed here.

### Mode C — Propose to user (interactive)

Surface 2-3 behavioral suggestions based on session patterns:
- "I noticed you always add X — should I automate that?"
- "This pattern appeared 3 times — should I add it to the project KB template?"

Wait for user response before taking any action.

### Mode D — Autonomous (low-risk only)

Apply these without asking:
- Tag KB entries whose features appear in `git log` as removed/archived
- Update `date` field on entries that were verified still accurate this session

Never autonomously change agent instruction files — those always require Mode C approval.

## Guardrails

- NEVER overwrite an instruction file without showing a diff first
- NEVER delete KB entries — only update `status` field
- Changes to `~/.claude/CLAUDE.md` or `~/.claude/rules/` require explicit user confirmation
- Changes to project `.claude/agents/` require diff review
