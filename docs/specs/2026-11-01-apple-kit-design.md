# apple-kit design

Date: 2026-11-01. Status: draft for review.

## Goal

One self-maintained plugin that lets Claude Code work with Apple apps on a Mac.
Version 0.1.0 has two skills:

- `apple-notes`: create, read, update, delete, and move Apple Notes. The end
  goal is that the user talks to the North Telegram bot, and North updates
  Apple Notes.
- `apple-health`: read weight and body fat from Apple Health into a body log
  in the LifeOS vault. The nutrition pipeline then reads that log.

Success criteria:

1. `apple-kit` 0.1.0 installs from the `21-breakincode` marketplace.
2. From a terminal session, the user can list, read, create, edit, move, and
   delete a note in a test folder. Each change asks for approval first.
3. From Telegram, North lists Notes folders, and changes a test note after the
   user replies "yes".
4. After the user taps the iPhone Shortcut, the 23:20 night job adds every new
   reading to `02Area/Health/Body/body-log.md`. A second run adds no rows.
5. The daily nutrition report shows the weight and body fat of the day from
   the body log.
6. The plugin holds no LifeOS paths. Every vault opinion lives in the vault
   file `.apple-kit.json`.

## Non-goals

- No Health data other than weight and body fat in 0.1.0. Steps, workouts,
  energy burned, and food are later candidates.
- No paid iPhone app. The user owns the whole export flow.
- No Apple Reminders, Calendar, or Messages skills yet.
- No native Notes tags, checklists, or heading styles. The chosen tool cannot
  write them through scripting.

## Anti-goals

- A script must never overwrite hand-written content. The vault has no
  version control, so a lost edit cannot come back.
- North must never change a note without a "yes" from the user in the same
  Telegram conversation.
- The plugin must never need Full Disk Access.

## Facts established before design

These were tested on the North Mac (macOS 26.6.2, MacBook Air M3) on
2026-11-01.

- macOS has no HealthKit store. A Mac process cannot read Health data
  (Apple docs; Apple engineer replies in the developer forums, 2025 and 2026).
- An iPhone app can read Health data only while the phone is unlocked.
- The Shortcut below works. Its output reached the Mac through iCloud Drive at
  `~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/apple-kit/health-latest.txt`.
  Shortcuts saves it as `.txt` even when the subpath ends in `.csv`.
- Observed output, complete (the scale app is Xiaomi Home):

  ```
  weight,2026-10-30T08:06:50+08:00,66.59999999999999,kg,Xiaomi Home
  weight,2026-10-31T12:53:23+08:00,66.09999999999999,kg,Xiaomi Home
  weight,2026-11-01T13:10:14+08:00,65,kg,Xiaomi Home
  body_fat,2026-10-30T08:06:50+08:00,18.9,%,Xiaomi Home
  body_fat,2026-10-31T12:53:23+08:00,18.8,%,Xiaomi Home
  body_fat,2026-11-01T13:10:14+08:00,18.2,%,Xiaomi Home
  ```

  Weight has float noise. Body fat is a percent, not a fraction. Weight and
  body fat of one weigh-in share one timestamp. Weigh-ins are not always in
  the morning (08:06, 12:53, 13:10).
- North (claude-code-telegram 1.3.0, launchd service) could not script Notes,
  for two reasons. Both are fixed:
  - The SDK's bundled Claude Code 2.1.139 lacks the Apple Events entitlement.
    North's `.env` now sets `CLAUDE_CLI_PATH` to the host Claude Code
    (2.1.316, auto-updating).
  - Claude Code's Bash sandbox blocks Apple Events. North's local patch 7 adds
    `"allowAppleEvents": True` to the sandbox dict. `excludedCommands` does
    not lift this block. A `sandbox` block in `.claude/settings.local.json`
    has no effect, because the SDK's sandbox dict replaces it.
- After both fixes, `osascript` from a launchd job waits for the macOS prompt
  "… wants to control Notes". Nobody has clicked Allow yet.
- `nutrition/diet_parse.py` reads Body lines with
  `^-\s*(體重|體脂)[:：]?\s*(\d+(?:\.\d+)?)\s*(kg|%)?\s*$`. A trailing marker
  such as `<!-- health -->` breaks that match.

## Plugin layout

```
apple-kit/
├─ .claude-plugin/plugin.json
├─ CHANGELOG.md
├─ skills/
│  ├─ apple-notes/SKILL.md        model-invoked
│  └─ apple-health/
│     ├─ SKILL.md                 model-invoked: sync, setup
│     └─ shortcut.md              iPhone Shortcut build steps
├─ scripts/
│  └─ health_sync.py              stdlib only, no Claude needed
└─ tests/
   └─ test_health_sync.py         fixture = the observed export above
```

Marketplace work: add the plugin to `.claude-plugin/marketplace.json`,
`content/plugins.content.json`, and `content/plugins.content.zh-TW.json`, then
run `./scripts/cicd.sh GEN` and `VERIFY`.

## Part 1: apple-notes

The skill wraps the `notes` command of `macnotesapp` (MIT, RhetTbull, 0.8.3).
The user chose this over `memo` (the tool in the Hermes skill), because every
`memo` write needs an editor or a numbered prompt, and its search flag is
broken. `macnotesapp` takes all input as flags, prints JSON, selects notes by
`--id`, and refuses ambiguous names.

Install (one time, needs user approval): `uv tool install macnotesapp==0.8.3`.

Operations:

| Intent | Command |
|---|---|
| list folders and notes | `notes accounts`, `notes list --json [TEXT]` |
| read | `notes cat --json --id ID` |
| create | `notes add -m -a ACCOUNT -f FOLDER` with Markdown on stdin; first line is the title |
| update | `notes edit --id ID -m --body …` |
| move | `notes move --id ID --folder F` |
| delete | `notes delete --id ID --yes` (goes to Recently Deleted for 30 days) |

Rules in the skill:

1. Always select by `--id`. Get the id from `list --json`.
2. Read the note (`cat --json`) before every edit, move, or delete, and show
   the user what changes.
3. Ask for approval before every create, edit, move, or delete. In a terminal,
   use the AskUserQuestion tool. In Telegram, where that tool is disabled, send
   the planned change as one message and act only on a "yes" reply.
4. Never pass `--force`. If `edit` refuses because the note has attachments,
   checklists, or tags, tell the user and stop.
5. Never run `rmdir` (folder delete). Open upstream issue #89 reports deleted
   folders that come back.

Error handling: exit 3 means not found, so list again. An Apple Events error
(-1743, "Not authorized") means the macOS permission is missing, so print the
one-time setup step and stop.

## Part 2: apple-health

### iPhone side

`shortcut.md` holds the build steps for the "Health Export" Shortcut, with an
ASCII picture of the finished Shortcut. The `.shortcut` file is a signed
binary, so the text steps are the source of truth.

1. Find Health Samples: type Weight, start date in the last 7 days, oldest
   first. Repeat with each: Text `weight,{Start Date ISO 8601},{Value},{Unit},{Source}`.
   Add to Variable `Rows`.
2. The same for Body Fat Percentage, with the prefix `body_fat,`.
3. Combine Text: input is the variable `Rows` (not `Repeat Results`), with New
   Lines.
4. Save File to Shortcuts, subpath `apple-kit/health-latest.csv`, Ask Where to
   Save off, Overwrite on.
5. Automation: App → Xiaomi Home → Is Closed → Run Immediately. The user also
   keeps the manual tap. The 7-day window fills missed days.

Pitfalls found while building: `Repeat Results` gets filled in by default after
`End Repeat` and repeats rows. Saving the list instead of the combined text
creates a folder of one-line files.

### Mac side: `scripts/health_sync.py`

Input: `--config PATH` to `.apple-kit.json`. Output: rows appended to the body
log, and one summary line on stdout (for Telegram). Exit 0 on success, also
when there is nothing new. Exit 1 with a clear message when the export file is
missing or older than 8 days.

1. Read the export. Skip blank and malformed lines and count them.
2. Drop duplicates by (type, timestamp).
3. Pair weight and body fat that share a timestamp into one reading.
4. Round weight to 0.1 kg and body fat to 0.1 %.
5. Read the existing log. Append readings whose timestamp is not in it. A
   reading with only one value gets an empty cell for the other.
6. If a later export brings the missing value for a timestamp already in the
   log, fill that empty cell. Never change a cell that has a value.
7. Write with an atomic replace (temp file, then rename).
8. Print nothing on success, to match the night job's "silent on success"
   rule. Print one line when the export file is missing, or when its newest
   reading is exactly 8 days old. The exact-day check gives one nudge, then
   quiet, with no state file.

The log is machine-owned. A wrong reading gets fixed in the Health app, or
overridden by a hand-written line in the intake note (Part 3). A row deleted by
hand comes back while its reading is still in the 7-day export window.

Body log format, `02Area/Health/Body/body-log.md`, one row per reading, oldest
first:

```markdown
| date | time | weight_kg | body_fat_pct | source |
|---|---|---|---|---|
| 2026-10-30 | 08:06 | 66.6 | 18.9 | Xiaomi Home |
```

Date and time are the local time of the reading.

Config, `.apple-kit.json` at the vault root:

```json
{
  "health": {
    "export_path": "~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/apple-kit/health-latest.txt",
    "body_log": "02Area/Health/Body/body-log.md"
  }
}
```

The skill's two branches: "sync health" runs the script with
`${CLAUDE_PLUGIN_ROOT}/scripts/health_sync.py`. "set up health export" walks the
user through `shortcut.md`.

## Part 3: LifeOS-side changes

These are vault changes, not plugin files.

1. `.apple-kit.json` at the vault root, as above.
2. `nutrition/diet_daily.py` (`run_calc`, today reads Body values only from
   the intake note at line 213): pick each value (weight, body fat) on its own.
   A hand-written `## Body` line in the intake note wins, because hand entry
   means a correction. Otherwise use the earliest body-log value of that local
   date. Log values are shown in the report only and are never written into
   the intake note. The 13 intake notes with hand-written Body lines stay as
   they are.
3. `nutrition/daily_nutrition_enrich.py` (23:20 night job): run
   `health_sync.py` before the calc step. A cron job has no
   `${CLAUDE_PLUGIN_ROOT}`, so the night job reads the plugin's `installPath`
   from `~/.claude/plugins/installed_plugins.json`, using the entry with
   `"scope": "user"`. If the plugin is missing, the job prints one warning line
   and continues. (Plugin rule 1 forbids a `find` lookup inside the plugin.
   This lookup is in the vault and reads a recorded field.)
4. North can see plugins only through project and local settings
   (`setting_sources=["project","local"]`). Add `apple-kit@21-breakincode` to
   `enabledPlugins` in the vault's `.claude/settings.local.json`. That file is
   local to the North Mac. The shared `.claude/settings.json` syncs to the
   other Mac through `03Resource/symlink/claude/`, so it is the wrong place.
5. North's `CLAUDE.md`: add `apple-notes` to the skills that stay in Telegram,
   with the yes-reply rule.
6. One-time, at the Mac screen: trigger a North Notes command and click Allow.

## Risks

- UNVERIFIED: the Claude Agent SDK honors `enabledPlugins` from local
  settings. If it does not, North cannot load the skill. The fallback is a
  vault-local copy of the apple-notes SKILL.md.
- UNVERIFIED: which app name the macOS prompt shows for North.
- `macnotesapp` issues #86 and #89 (macOS 27, iCloud): scripted changes were
  saved late, and deleted folders came back. Not seen on macOS 26.
- North follows Claude Code auto-updates. A future update can break the old
  SDK 0.1.81. North's 3 daily reminders show this within hours.
- The Health export lowers protection: Health data in iCloud is end-to-end
  encrypted, but iCloud Drive files are not, unless Advanced Data Protection
  is on.

## Verification

1. `tests/test_health_sync.py`: the observed 6-line export gives 3 rows. A
   second run adds none. A 15-line export with repeated rows still gives 3
   rows. A weight-only reading gets its body fat filled by a later export.
2. Terminal smoke test in a `ClaudeTest` Notes folder: create, read, edit,
   move, delete.
3. Telegram smoke test: list folders, then edit a test note after "yes".
4. Night job dry run on 2026-11-01: body log gets new rows, and the daily
   report shows `體重 65.0kg | 體脂 18.2%`.

## Left to the builder

- Exact SKILL.md wording, following `.claude/rules/writing-great-skills.md`.
- Test runner choice, matching the other plugins' `tests/` folders.
- Content-file tagline and summary text.
