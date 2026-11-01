---
name: apple-notes
description: Create, read, edit, move, or delete notes in the Apple Notes app on this Mac. Use when the user asks to find, read, write, update, or remove an Apple Note, or to list Notes folders.
---

# apple-notes

Apple Notes is the user's own data, and a lost edit cannot come back. Treat
every change as a **guarded write**: find the note by id, read it, check what
the change would lose, show the change, get a "yes", then write.

All access goes through the `notes` command of `macnotesapp`, pinned to
GitHub commit `d2b155a` (it reports version 0.8.3, but the PyPI 0.8.3
release lacks `--id` and the edit guard).

## Operations

| Intent | Command |
|---|---|
| list folders | the unique `.folder` values of `notes list --json` (folders with no notes do not appear) |
| find notes | `notes list --json "TEXT"` (metadata and id, no body) |
| read | `notes cat --json -m "TITLE"` (Markdown body; prints every match, each with its id) |
| create | `notes add -m -a ACCOUNT -f FOLDER 'TITLE` … `BODY'` (one argument: first line is the title) |
| update | `notes edit --id ID -m --body 'BODY'` |
| move | `notes move --id ID --folder FOLDER` |
| delete | `notes delete --id ID --yes` |

Pass note text as one single-quoted argument. It can span lines. Write each
`'` inside it as `'\''`. The shell expands nothing inside single quotes. For
create, the first line becomes the title as typed, so it carries no `#`.

Run each `notes` command alone: no heredoc, `$(…)`, redirect, `cd`, or pipe to
another command. In a sandboxed agent, any of these keeps the call inside the
sandbox, where Notes is unreachable.

Reads need no approval. A deleted note goes to Recently Deleted for 30 days.

## Guarded write

Every update, move, and delete follows these steps. Create skips steps 1 to 3.

1. Get the note's id from `notes list --json "TEXT"`. If several notes match,
   show their titles and folders, and ask which one.
2. Read it with `notes cat --json -m "TITLE"` and take the entry with that id.
   The body's first line is the title: drop it before you build `--body`,
   because `edit` keeps the title by itself.
3. For an update, check the body from step 2 for lists or checklists,
   tables, images or attachments, underline or strikethrough, fonts or
   colors, and tags. If it has any, tell the user to make this edit in the
   Notes app, and stop. The apple-kit hook enforces the same check when
   `notes edit` runs.
4. Show the user the planned change: the note's title and folder, and the old
   and new text, or the target folder.
5. Get approval. When the AskUserQuestion tool exists, use it. Otherwise (for
   example in a Telegram bot), send the plan as one message and act only on a
   "yes" reply in the next message.
6. Run the one command. Then read the result: for a create, find the new note
   with `notes list --json "TITLE"` in the target folder; otherwise read it
   again by its title.

Done when the re-read shows the approved change, or the user declined.

## Limits

- Use `edit` with `--id` and without `--force`. The hook blocks any other
  form. If the hook or `edit` itself refuses, tell the user and stop.
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
| "Not allowed to control Notes" | macOS blocked Notes access | Tell the user: click Allow on the Mac's "… wants to control Notes" prompt, or turn it on in System Settings → Privacy & Security → Automation. Then stop |
| `apple-kit notes guard: …` | the hook blocked the edit | Tell the user the reason. For lost content, the user edits in the Notes app. Then stop |
| `-600` from a sandboxed agent | the Bash sandbox blocks Apple Events | Run `notes` alone in the call. If it still fails, the host must add `notes *` to `sandbox.excludedCommands` and allow `Bash(notes *)`. Then stop |
