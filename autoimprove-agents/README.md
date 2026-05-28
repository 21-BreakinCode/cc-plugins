# autoimprove-agents

Modular CLAUDE.md + project/cross-project KB + self-improvement loop.

## What it does

Manages a modular CLAUDE.md architecture with principles up top and details referenced elsewhere. Maintains per-project and cross-project knowledge bases backed by local files and optionally NotebookLM. Runs a self-improvement loop that accumulates knowledge, proposes instruction refinements, and applies low-risk updates automatically.

## Prerequisites

- `jq` (recommended) -- `brew install jq`
- `notebooklm-py` (optional) -- `pip install notebooklm-py`

## Install

1. Copy this plugin directory to `~/.claude/plugins/local/autoimprove-agents/`
2. Copy `config/config.example.sh` to `~/.claude/autoimprove-agents/config.sh`
3. Customize `config.sh` with your settings
4. Run `/autoimprove-agents:init` in any project to set up modular CLAUDE.md

## Commands

| Command | Description |
|---|---|
| `/autoimprove-agents:init` | Initialize modular CLAUDE.md architecture for the current project |
| `/autoimprove-agents:sync-kb` | Extract learnings from the current session and write them to the project KB |
| `/autoimprove-agents:review-kb` | Review project KB entries -- list active entries and mark stale ones as archived |
| `/autoimprove-agents:self-improve` | Review and apply self-improvement proposals for agent instruction files |

## Self-Improvement Modes

| Mode | Name | Description |
|---|---|---|
| A | Refine instructions | Analyze KB entries, propose diffs to agent instruction files, apply on user approval |
| B | Accumulate knowledge | KB entries written via `sync-kb` -- no additional action needed |
| C | Propose to user | Surface 2-3 behavioral suggestions based on session patterns, wait for user response |
| D | Autonomous low-risk | Auto-tag KB entries for archived features, update dates on verified entries |

## Configuration

All env vars are set in `~/.claude/autoimprove-agents/config.sh`.

| Variable | Default | Description |
|---|---|---|
| `AUTOIMPROVE_NOTEBOOKLM_ENABLED` | `false` | Enable NotebookLM integration (requires `notebooklm-py`) |
| `AUTOIMPROVE_AUTO_APPLY_LOW_RISK` | `true` | Auto-apply low-risk self-improvement changes (Mode D) |
| `AUTOIMPROVE_CROSS_PROJECT_NOTEBOOK` | `claude-cross-project-kb` | Name of the cross-project NotebookLM notebook |
| `AUTOIMPROVE_GOOGLE_ACCOUNT` | `""` | Google account email for NotebookLM (required if NotebookLM enabled) |
