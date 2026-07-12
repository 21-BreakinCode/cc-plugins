---
name: distill
description: Use to capture a writing voice into a reusable tone preset from samples or referenced materials. Triggers on "distill my voice / tone", "make a tone preset from these posts", or "capture the writing style of X". The preset it produces is consumed by humanize:rewrite.
---

# Distill (materials → tone preset)

Turn writing samples into a reusable tone preset file. This reads existing
material and describes its voice. It never invents a persona the samples don't show.

## 1. Gather materials
Accept file paths or a prompt naming specific materials (past posts, PRs, notes).
Read them with `Read`/`Glob`. If given nothing concrete, ask for at least one sample.

## 2. Extract the voice
Identify, grounded in the samples (quote where you can):
- **Voice** (the persona/register in one line).
- **Diction** (preferred words, banned words).
- **Rhythm** (sentence-length pattern, paragraph shape).
- **Quirks** (recurring habits to reproduce, or avoid).
- **Do / Don't** (short bullets).
- **Examples** (1 to 2 verbatim lines from the samples that exemplify the voice).
- **Language** (`en`, `zh-TW`, or `auto` based on the samples).

## 3. Emit the preset
Format (must match what humanize:rewrite consumes):

```markdown
---
name: <kebab-name>
language: <en|zh-TW|auto>
---
# <name>
- **Voice:** …
- **Diction:** …
- **Rhythm:** …
- **Quirks:** …
- **Do / Don't:** …
- **Examples:** …
```

## 4. Write it
- `$HUMANIZE_TONE_DIR` set → write `$HUMANIZE_TONE_DIR/<name>.md`. If that file
  already exists, show the diff and ASK before overwriting.
- `$HUMANIZE_TONE_DIR` unset → print the preset to the terminal and tell the user
  to set `HUMANIZE_TONE_DIR` (a folder of their tone presets) then re-run, or save
  it manually. Do not guess a location.
