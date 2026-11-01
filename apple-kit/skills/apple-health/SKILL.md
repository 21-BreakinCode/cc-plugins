---
name: apple-health
description: Sync Apple Health weight and body fat into the vault's body log, or set up the iPhone export that feeds it. Use when the user asks to sync health, weight, or body fat data, or to set up the Health export Shortcut.
---

# apple-health

macOS cannot read Apple Health. An iPhone Shortcut exports weight and body fat
to iCloud Drive, and `health_sync.py` adds them to a body log in the vault.
The vault file `.apple-kit.json` holds both paths.

## Branch: sync

1. Run from the vault root:

   ```bash
   python3 -B "${CLAUDE_PLUGIN_ROOT}/scripts/health_sync.py" --config "$PWD/.apple-kit.json"
   ```

2. Read the result:
   - Exit 0 and no output: the body log is current. Report how many rows it
     has for the last 7 days.
   - Exit 0 and a "no new weigh-in" line: relay it once.
   - Exit 1 "health export not readable (FileNotFoundError)": the Shortcut
     has not run, or iCloud has not delivered the file yet. Suggest one tap on
     the Shortcut, then a retry in a minute. Another error name (for example
     `PermissionError`) means macOS blocked the read: relay it as is.
   - "skipped N export lines": the Health unit is not kg, or a line is broken.
     Ask the user to set Health weight to kg.
   - `.apple-kit.json` missing: switch to the setup branch.

Done when the command exited 0 and you reported the body log's newest row.

## Branch: setup

1. Walk the user through [shortcut.md](shortcut.md), one numbered step at a
   time, until they ran the Shortcut once.
2. Check that the export file exists on the Mac.
3. Ask for approval, then write `.apple-kit.json` at the vault root:

   ```json
   {
     "health": {
       "export_path": "~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/apple-kit/health-latest.txt",
       "body_log": "Health/body-log.md"
     }
   }
   ```

   Use the body log path the user picks. It is relative to the vault root.
4. Run the sync branch.

Done when the sync branch finished with exit 0.

## The body log

The log is a Markdown table, one row per reading, oldest first:
`| date | time | weight_kg | body_fat_pct | source |`. The script owns it: it
adds rows and fills empty cells, and never changes a value. To correct a
reading, fix it in the Health app, or write the correct value by hand in the
note that consumes it.
