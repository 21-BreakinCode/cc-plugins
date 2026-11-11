---
name: apple-health
description: Sync Apple Health weight, body fat, and sleep into the vault's body log and sleep log, or set up the iPhone export that feeds them. Use when the user asks to sync health, weight, body fat, or sleep data, or to set up the Health export Shortcut.
---

# apple-health

macOS cannot read Apple Health. An iPhone Shortcut exports weight, body fat,
and sleep stages to iCloud Drive. `health_sync.py` adds weight and body fat to
a body log, and `sleep_sync.py` turns sleep stages into one row per night in a
sleep log. The vault file `.apple-kit.json` holds the paths.

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

   If `.apple-kit.json` has a `sleep` key, also run:

   ```bash
   python3 -B "${CLAUDE_PLUGIN_ROOT}/scripts/sleep_sync.py" --config "$PWD/.apple-kit.json"
   ```

   Exit 1 "sleep export not readable" has the same causes as the health export.

Done when the command exited 0 and you reported the body log's newest row
(and the sleep log's newest night, if sleep is set up).

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
     },
     "sleep": {
       "export_path": "~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/apple-kit/sleep-latest.txt",
       "sleep_log": "Health/sleep-log.md"
     }
   }
   ```

   Use the log paths the user picks. They are relative to the vault root.
   Leave out the `sleep` key if the user does not export sleep.
4. Run the sync branch.

Done when the sync branch finished with exit 0.

## The body log

The log is a Markdown table, one row per reading, oldest first:
`| date | time | weight_kg | body_fat_pct | source |`. The script owns it: it
adds rows and fills empty cells, and never changes a value. To correct a
reading, fix it in the Health app, or write the correct value by hand in the
note that consumes it.

## The sleep log

One row per night, oldest first:
`| night | bed | wake | asleep | deep | rem | awake | utc |`. A night is the
local date of bedtime minus 12 hours, so 03:38 on 11-11 is night 11-10. Asleep
is the union of `Core`, `Deep`, `REM`, and `Asleep` samples, so two apps that
record the same night do not double count. A session that starts from 12:00
to 17:59 is a nap and is left out. Each row keeps the UTC offset of its night,
so travel needs no setting. The export is the truth for the nights it holds,
and the script rewrites their rows. The oldest night of an export can be cut
by the export window, so it only fills a missing row.
