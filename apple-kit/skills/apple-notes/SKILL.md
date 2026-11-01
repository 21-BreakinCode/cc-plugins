---
name: apple-notes
description: Create, read, edit, move, or delete notes in the Apple Notes app on this Mac. Use when the user asks to find, read, write, update, or remove an Apple Note, or to list Notes folders.
---

# apple-notes

Apple Notes is the user's own data, and a lost edit cannot come back. Treat
every change as a **guarded write**: find the note by id, read it, show the
change, get a "yes", then write.

All access goes through the `notes` command of `macnotesapp`, pinned to
GitHub commit `d2b155a` (it reports version 0.8.3, but the PyPI 0.8.3
release lacks `--id` and the edit guard).

## Operations

| Intent | Command |
|---|---|
| list accounts and folders | `notes accounts`, `notes list --json` |
| find notes | `notes list --json "TEXT"` (metadata and id, no body) |
| read | `notes cat --json "TITLE"` (prints every match, each with its id) |
| create | `printf '%s' "$MARKDOWN" \| notes add -m -a ACCOUNT -f FOLDER`; the first line is the title |
| update | `notes edit --id ID -m --body "MARKDOWN"` (replaces the body, keeps the title) |
| move | `notes move --id ID --folder FOLDER` |
| delete | `notes delete --id ID --yes` |

Reads need no approval. A deleted note goes to Recently Deleted for 30 days.

## Guarded write

Every create, update, move, and delete follows these steps:

1. Get the note's id from `notes list --json`. If several notes match, show
   their titles and folders, and ask which one.
2. Run `notes cat --json "TITLE"`, take the entry with that id, and keep its
   current body.
3. Show the user the planned change: the note's title and folder, and the old
   and new text, or the target folder.
4. Get approval. When the AskUserQuestion tool exists, use it. Otherwise (for
   example in a Telegram bot), send the plan as one message and act only on a
   "yes" reply in the next message.
5. Run the one command, then read the note again to show the result.

Done when the re-read shows the approved change, or the user declined.

## Limits

- Use `edit` without `--force`. If `edit` refuses because the note has
  attachments, checklists, or tags, tell the user that the change would lose
  them, and stop.
- Leave folders in place: `notes rmdir` is out of scope, because upstream
  issue #89 reports deleted folders that come back. Tell the user to delete a
  folder in the Notes app.
- Notes can be created in, and moved to, top-level folders only.
- A locked note lists with an empty body. Tell the user to unlock it in Notes.

## Errors

| Signal | Meaning | Action |
|---|---|---|
| `notes: command not found` | tool missing | Ask, then run `uv tool install "git+https://github.com/RhetTbull/macnotesapp@d2b155a"` |
| exit 3, "not found" | note not found | List again and confirm the id |
| "N notes match …; select one with --id" | several notes share the title | Show the listed candidates and ask which one |
| `-1743` or "Not authorized" | macOS blocked Notes access | Tell the user: click Allow on the Mac's "… wants to control Notes" prompt, or turn it on in System Settings → Privacy & Security → Automation. Then stop |
| `-600` from a sandboxed agent | the Bash sandbox blocks Apple Events | The host needs `"allowAppleEvents": true` in its sandbox settings. Then stop |
