# humanize

> Sound like a person, in zh-TW or English

Two skills. distill captures your voice from writing samples into a reusable tone preset; rewrite strips AI-tells from existing text (PR comments, posts, emails) and matches a tone, preserving meaning and never inventing facts. Separate Traditional-Chinese and English rulesets, auto-detected, plus a flag-only audit mode.

## Install

```bash
claude plugin install humanize@21-breakincode
```

## Skills

Invoke one directly as `/humanize:<skill>`, or let it activate automatically when relevant.

- **`distill`** — Use to capture a writing voice into a reusable tone preset from samples or referenced materials.
- **`rewrite`** — Use to humanize / de-AI existing text — PR review comments, posts, emails, docs — in Traditional Chinese (zh-TW) or English, preserving mea…

## Configuration

| Variable | Default | Description |
|---|---|---|
| `HUMANIZE_TONE_DIR` | `—` | Folder of your own tone preset .md files. Overrides the built-in presets by name, and is where `distill` writes new presets. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
