---
name: rewrite
description: Use to humanize / de-AI existing text (PR comments, posts, emails, docs) in Traditional Chinese (zh-TW) or English, preserving meaning. Triggers on "humanize this", "make this sound less like AI / ChatGPT", "去AI味", "rewrite my PR comment to sound human", or "check my draft for AI-tells" (flag-only).
---

# Rewrite (humanize existing text)

Reshape existing text so it reads like a person wrote it, without changing what
it says. This does NOT generate new content, it only rewrites material you give it.

## Before anything, obey the safety rails
Read `${CLAUDE_PLUGIN_ROOT}/references/safety-rails.md` and apply it in order.
If the human-detection gate trips (input is already genuinely human), STOP,
clean only formatting, and say why.

## 1. Detect language
- Traditional-CJK characters → use `${CLAUDE_PLUGIN_ROOT}/references/ai-tells-zhtw.md`.
- Latin script → use `${CLAUDE_PLUGIN_ROOT}/references/ai-tells-en.md`.
- Mixed → apply both to their respective spans.
- **Simplified Chinese detected** → warn: this ruleset targets Traditional
  Chinese (Taiwan); offer to run the TW-localization pass (vocab swap +
  punctuation) rather than treating it as native. Do not silently proceed.
- An explicit target language in the request overrides detection.

## 2. Resolve tone
Preset name given? Resolve `$HUMANIZE_TONE_DIR/<name>.md` first, else
`${CLAUDE_PLUGIN_ROOT}/presets/<name>.md`. No name, or no match → proceed with
no preset: apply the language reference and safety rails only, and say you
used no tone preset.

## 3. Mode
- **Default (transform):** rewrite to remove the clustered AI-tells from the
  language reference and match the tone. Preserve meaning; keep one rough edge;
  English output must contain zero em/en dashes.
- **`--flag-only` (audit):** do NOT edit. List each tell found as
  `original / why it's a tell / suggested fix`, then give a /50 score across
  directness, rhythm, trust, authenticity, concision (<35 = rewrite, 45+ = ship).

## 4. Delivering
- **Pasted text** → output the rewrite inline in the terminal. No file write.
- **A file** (transform mode) → first list the numbered edits
  (`original / why / suggested`) and ASK "Which of these N do you want applied?".
  WAIT for the reply. Only then edit the file, applying only approved edits.

## Output (transform mode)
Show, in order: the rewrite; then a short "changed:" list (what you cut and why).
For English, confirm "0 em-dashes" in the changed list.
