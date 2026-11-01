# Changelog

## 0.1.1 — 2026-11-01

- **fix:** `apple-notes` works inside Claude Code's Bash sandbox. Note text is one single-quoted argument, not a heredoc or `$(…)`, and each `notes` command runs alone, so a host can exclude `notes *` from the sandbox.
- **feat:** `notes_guard.py` is now a PreToolUse hook. It blocks a `notes edit` without `--id`, with `--force`, or on a note with lists, tables, images, styling, or tags. Hooks run outside the sandbox, so the check reads the note by id with `osascript`.

## 0.1.0 — 2026-11-01

- **feat:** `apple-notes` skill. It wraps the `notes` command of macnotesapp, pinned to GitHub commit `d2b155a` for `--id` selection and the attachment-safe edit. Every create, edit, move, and delete is a guarded write: find by id, read, check losses with `notes_guard.py`, show the change, get a yes, write, re-read. Note text goes through a quoted heredoc.
- **feat:** `apple-health` skill and `health_sync.py`. The script syncs weight and body fat from the iPhone Health Export Shortcut into a Markdown body log. It adds rows, fills empty cells, never changes a value, and prints nothing on success.
