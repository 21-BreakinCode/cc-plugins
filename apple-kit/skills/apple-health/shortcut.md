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

## Automation

Shortcuts → Automation → New Automation → App → `Xiaomi Home` (or the app of
your scale) → Is Closed only → Run Immediately → `Health Export`.

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

On the Mac the file is at
`~/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/apple-kit/health-latest.txt`.
