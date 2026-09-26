---
name: migrate-notes
description: One-time vault migration to set note-type and rename map notes by plan approval.
disable-model-invocation: true
---

# migrate-notes

Run every command from the vault root. Obsidian must be open. `$N` is
`${CLAUDE_PLUGIN_ROOT}/scripts/notes`. `<work>` is a folder in the scratchpad.

1. **Plan:** `python3 $N/migrate.py plan <work>`. It writes `<work>/migrate-plan.tsv`.
2. **Show the plan** to the user: counts by note_type, every map rename, every
   `rename target exists` row, and every unset row. Ask the user to decide the unset
   rows: a type, or leave empty to skip.
3. Edit the TSV with the user's decisions. Do not apply until the user approves the
   whole plan once.
4. **Apply:** `python3 $N/migrate.py apply <work>`. `obsidian move` updates wikilinks.
5. Report the log path `<work>/migrate-log.md`. Each move line carries its undo command.
   If apply stops on an error, report the failing row and ask before running again.
