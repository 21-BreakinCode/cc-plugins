---
description: "Promote a draft note from Obsidian inbox to permanent location"
allowed-tools: ["Read", "Write", "Bash", "Glob"]
---

# zettelkasten-capture: Finalize

Promote a draft note from the Obsidian inbox to its permanent location in the vault.

## Steps

1. List all draft notes in `$ZC_OBSIDIAN_VAULT/$ZC_INBOX_FOLDER/` with `status: draft`
2. If multiple drafts exist, ask user which to finalize
3. Read the draft note
4. Ask user to confirm or update: title, tags, target folder (default: vault root or a topic folder)
5. Move the note from inbox to permanent location using `mv`
6. Update frontmatter: `status: draft` → `status: permanent`
7. If `ZC_AUTO_PUSH_TO_KB=true` and `autoimprove-agents` is installed, run `/zettelkasten-capture:push-to-kb`
8. Confirm: "Note finalized: [[note-title]]"

## Config

Reads from `~/.claude/zettelkasten-capture/config.sh`:
- `ZC_OBSIDIAN_VAULT` — vault path
- `ZC_INBOX_FOLDER` — inbox subfolder
- `ZC_AUTO_PUSH_TO_KB` — auto-push on finalize
