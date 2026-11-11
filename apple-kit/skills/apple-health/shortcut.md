# Health Export Shortcut

This file is the source of truth for the iPhone side. A `.shortcut` file is a
signed binary, so rebuild the Shortcut from these steps on any phone.

## The finished Shortcut

```
┌─ Health Export ───────────────────────────────────────┐
│ ① Find [All Health Samples] where                     │
│      Type        is  Weight                           │
│      Start Date  is in the last  7 days               │
│    Sort by Start Date   Order Oldest First            │
│ ② Repeat with each item in [Health Samples ①]         │
│   │ Text  weight,[Start Date],[Value],[Unit],[Source] │
│   │ Add [Text] to variable [Rows]                     │
│   End Repeat                                          │
│ ③ Find ... Type is Body Fat Percentage  (same as ①)  │
│ ④ Repeat with each item in [Health Samples ③]         │
│   │ Text  body_fat,[Start Date],[Value],[Unit],[Source]│
│   │ Add [Text] to variable [Rows]                     │
│   End Repeat                                          │
│ ⑤ Combine [Rows] with [New Lines]                     │
│ ⑥ Save [Combined Text] to Shortcuts                   │
│      Subpath: apple-kit/health-latest.csv             │
│      Ask Where to Save: OFF   Overwrite: ON           │
└───────────────────────────────────────────────────────┘
```

## Build steps

1. Create a shortcut named `Health Export`.
2. Add "Find Health Samples". Set Type to `Weight`. Add the filter
   `Start Date is in the last 7 days`. Sort by `Start Date`, Oldest First.
3. Add "Repeat with Each". It uses the samples of step 2.
4. Inside the loop, add "Text". Type `weight,`, then insert `Repeat Item` from
   the bar above the keyboard. Tap the blue bubble and pick `Start Date`. Tap
   it again and set Date Format to ISO 8601 with the time included. Then type
   `,` and insert `Repeat Item` → `Value`, then `,` and `Unit`, then `,` and
   `Source`.
5. Inside the loop, under Text, add "Add to Variable" with the name `Rows`.
6. Repeat steps 2 to 5 for Type `Body Fat Percentage`, with the prefix
   `body_fat,`. Make sure the second loop uses the samples of the body fat
   Find action.
7. Below the last `End Repeat`, add "Combine Text". Set its input to the
   variable `Rows`, separator New Lines.
8. Add "Save File". Destination Shortcuts, subpath `apple-kit/health-latest.csv`,
   Ask Where to Save off, Overwrite If File Exists on. Shortcuts saves the file
   as `health-latest.txt`.
9. Run it once and allow Health access.

## Sleep export

Add these actions to `Health Export`, below the body fat `End Repeat`:

1. "Find Health Samples", Type `Sleep` (some iOS versions say `Sleep
   Analysis`), `Start Date is in the last 3 days`, sorted by `Start Date`,
   Oldest First.
2. "Repeat with Each" over those samples. Inside, a "Text" action:
   `sleep,[Repeat Item→Start Date],[Repeat Item→End Date],[Repeat Item→Value],[Repeat Item→Source]`.
   Insert each field from `Repeat Item`, not from `Health Samples`: a chip with
   a heart icon reads the whole list. Both dates use ISO 8601 with the time.
3. Inside the loop, "Add to Variable" `SleepRows`.
4. Below `End Repeat`: "Combine Text" `SleepRows` with New Lines, then "Save
   File" to Shortcuts, subpath `apple-kit/sleep-latest.csv`, Ask Where to Save
   off, Overwrite on. Check that the old Save still takes the Combine of `Rows`.
5. Settings → Apps → Shortcuts → Advanced → turn on "Allow Sharing Large
   Amounts of Data". Three nights are about 190 samples, and iOS blocks that
   many Health items without this setting.

Backfill, once: set the sleep Find to the last 90 days, run the Shortcut, run
`sleep_sync.py`, then set it back to 3 days.

## Morning Gate

A second shortcut, `Morning Gate`, runs the export once after you wake:

1. "Get File" `apple-kit/last-run.txt` from Shortcuts, Error If Not Found off.
   If it holds a time less than 3 hours ago: "Stop This Shortcut".
2. "Find Health Samples", Type `Sleep`, `End Date is today`, Limit 1. If
   there is no sample: stop.
3. "Run Shortcut" `Health Export`.
4. "Save File" the current date and time to `apple-kit/last-run.txt`,
   Overwrite on.

The 3-hour lock (not one day) lets a later open export the rest of a night
when an early open caught only part of it.

## Automation

Shortcuts → Automation → New Automation → App → `Xiaomi Home` (or the app of
your scale) → Is Closed only → Run Immediately → `Health Export`.

For sleep: New Automation → App → the app you open first after you wake (for
example `Obsidian`) → Is Opened → Run Immediately, Notify When Run off →
`Morning Gate`.

Health data is readable only while the phone is unlocked, and closing the
scale app always happens on an unlocked phone. A manual tap also works. The
7-day window fills in any missed day.

## Pitfalls

- Combine Text fills in `Repeat Results` by default after `End Repeat`. That
  input repeats rows. Pick the variable `Rows`.
- If Save File gets the `Rows` list instead of the combined text, Shortcuts
  saves a folder of one-line files.
- iCloud Drive can take a minute or more to deliver the file to the Mac.

## Output

One line per sample:

```
weight,2026-10-30T08:06:50+08:00,66.59999999999999,kg,Xiaomi Home
body_fat,2026-10-30T08:06:50+08:00,18.9,%,Xiaomi Home
```

Sleep, one line per stage sample:

```
sleep,2026-11-11T03:38:04+07:00,2026-11-11T04:10:04+07:00,Core,Apple Watch
```

On the Mac the files are in
`~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/apple-kit/`
as `health-latest.txt` and `sleep-latest.txt`.
