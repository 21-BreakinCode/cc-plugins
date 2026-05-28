# zettelkasten-capture

Transform Claude session output into structured Obsidian Zettelkasten notes.

## What it does

Runs after session-learner on session end. Structures raw session output into a Zettelkasten note template with tags, insights, and optional Excalidraw stubs. Places drafts in your Obsidian inbox for human review and finalization.

## Prerequisites

- `session-learner` plugin (soft dependency -- works without it but captures less context)
- Obsidian vault

## Install

1. Copy this plugin directory to `~/.claude/plugins/local/zettelkasten-capture/`
2. Copy `config/config.example.sh` to `~/.claude/zettelkasten-capture/config.sh`
3. Set `ZC_OBSIDIAN_VAULT` to the path of your Obsidian vault
4. Customize remaining settings as needed

## Commands

| Command | Description |
|---|---|
| `/zettelkasten-capture:finalize` | Promote a draft note from Obsidian inbox to its permanent location in the vault |
| `/zettelkasten-capture:push-to-kb` | Push a finalized Obsidian note to the project knowledge base (requires autoimprove-agents) |

## Integration

Works with `autoimprove-agents` for KB push (optional). When `ZC_AUTO_PUSH_TO_KB=true` and the `autoimprove-agents` plugin is installed, finalized notes are automatically pushed to the project knowledge base. Notes can also be pushed manually via `/zettelkasten-capture:push-to-kb`.

## Configuration

All env vars are set in `~/.claude/zettelkasten-capture/config.sh`.

| Variable | Default | Description |
|---|---|---|
| `ZC_OBSIDIAN_VAULT` | `/path/to/your/obsidian/vault` | **Required.** Path to your Obsidian vault |
| `ZC_INBOX_FOLDER` | `Inbox` | Folder within vault for inbox drafts (created if missing) |
| `ZC_EXCALIDRAW_THRESHOLD` | `1` | Auto-create Excalidraw stub when architecture/diagram references detected |
| `ZC_AUTO_PUSH_TO_KB` | `false` | Push finalized notes to autoimprove-agents KB automatically |
| `ZC_SESSIONS_DIR` | `~/.claude/sessions` | Override session-learner sessions directory if non-default |
