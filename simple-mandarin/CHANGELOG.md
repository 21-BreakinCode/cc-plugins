## 0.2.1 — 2026-09-24

- **fix:** the Stop hook no longer flags headers, bold, or bullets, and its message states the current reply rule (no em-dashes, no opener or closer). Commit 743265a removed the old formatting rule from the style and the skill, but the hook still printed it.
- **fix:** both lint hooks skip text with no Han characters. Before, English files and English replies got em-dash reports.

## 0.2.0 — 2026-09-20

- **fix:** remove formatting-shape restrictions (no bold, no bullets, no headers, no tables) from reply rules to avoid conflict with adhd-review output style

## 0.1.0 — 2026-09-20

- **feat:** initial release. A `simple-mandarin` skill covers rewriting
  on request and rule-catalog checks. An always-on SessionStart hook
  loads the ruleset. An advisory PostToolUse/Stop hook checks
  Traditional Chinese technical writing.
