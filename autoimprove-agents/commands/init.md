---
description: "Initialize modular CLAUDE.md architecture for the current project"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
---

# autoimprove-agents: Init

Set up modular CLAUDE.md architecture for the current project.

## Steps

1. Read existing `CLAUDE.md` in current directory (if any)
2. Read `~/.claude/CLAUDE.md` (global)
3. Create `.claude/` directory in project root if it doesn't exist
4. Generate a lean project `CLAUDE.md`:
   - Project name and purpose (1-2 sentences)
   - Reference to global rules: `See ~/.claude/rules/coding-style.md for coding standards`
   - Reference to global rules: `See ~/.claude/rules/git-workflow.md for commit format`
   - Any project-specific overrides or additions (extracted from existing CLAUDE.md)
   - Reference to agent: `See .claude/agents/project-kb.md for project knowledge agent`
5. Create `.claude/agents/project-kb.md` — project knowledge agent (see template below)
6. If global `~/.claude/CLAUDE.md` is over 50 lines, suggest extracting detail to `~/.claude/rules/`

## Project CLAUDE.md Template

```
# [Project Name]

[1-2 sentence project description]

## Standards
- Coding: see `~/.claude/rules/coding-style.md`
- Git: see `~/.claude/rules/git-workflow.md`
- [Any project-specific additions]

## Agents
- Project KB: see `.claude/agents/project-kb.md`
```

## Project KB Agent Template (`.claude/agents/project-kb.md`)

```
---
name: project-kb
description: Project-scoped knowledge agent. Query for patterns, decisions, and learnings specific to this project. Use PROACTIVELY when starting work on a feature or debugging.
tools: Read, Bash
---

# Project Knowledge Agent: [Project Name]

You are the knowledge agent for [Project Name]. You surface relevant past decisions,
patterns, and learnings to help the engineer work faster and avoid repeating mistakes.

## How to Use

Query me with: "What do we know about [topic]?"
I will search `~/.claude/autoimprove-agents/[project-name]/` for relevant entries.

## Knowledge Store Location

`~/.claude/autoimprove-agents/[project-name]/entries/`

Each entry is a markdown file with frontmatter:
- `status`: active | archived | historical
- `date`: YYYY-MM-DD
- `tags`: array of topic tags
```
