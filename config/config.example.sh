# zettelkasten-capture configuration
# Copy to ~/.claude/zettelkasten-capture/config.sh and customize

# Required: path to your Obsidian vault
export ZC_OBSIDIAN_VAULT="/path/to/your/obsidian/vault"

# Folder within vault for inbox drafts (created if missing)
export ZC_INBOX_FOLDER="Inbox"

# Auto-create excalidraw stub when architecture/diagrams detected
export ZC_EXCALIDRAW_THRESHOLD=1

# Push finalized notes to autoimprove-agents KB (requires autoimprove-agents plugin)
export ZC_AUTO_PUSH_TO_KB=false

# Override session-learner sessions directory if non-default
# export ZC_SESSIONS_DIR="${HOME}/.claude/sessions"
