# Changelog

## 0.1.0 — 2026-11-01

- **feat:** `apple-notes` skill. It wraps the `notes` command of macnotesapp, pinned to GitHub commit `d2b155a` for `--id` selection and the attachment-safe edit. Every create, edit, move, and delete is a guarded write: find by id, read, show the change, get a yes, write, re-read.
- **feat:** `apple-health` skill and `health_sync.py`. The script syncs weight and body fat from the iPhone Health Export Shortcut into a Markdown body log. It adds rows, fills empty cells, never changes a value, and prints nothing on success.
