## 2.0.0 — 2026-09-26

- **feat:** absorb `session-learner` as `session-wrap-up`, `session-pick-up`, and `session-recommend`. `session-pick-up` now writes cards into the vault after one approval.
- **feat:** absorb `hh` as `handover-new`, `handover-wrap-up`, `handover-init-org`, and `handover-init-service`.
- **feat:** absorb `simple-mandarin`. Its rules and lint now run only inside a vault.
- **fix:** handover discovery uses the Obsidian tag index and the current taxonomy. The old grep for the retired `handover` tag matched nothing.
- **fix:** archiving moves the file and never renames it, so wikilinks keep resolving. The living and historical reference classifier is gone.
- **refactor:** one vault resolver. `HH_LIFEOS_ROOT`, `HH_ARCHIVE_ROOT`, and `CLAUDE_SIMPLE_MANDARIN` are deleted. `OBSIDIAN_KIT_MANDARIN` and `OBSIDIAN_KIT_OFFER_HANDOVER` replace the two behavior toggles.

## 1.1.0 — 2026-09-26

- **feat:** absorb the three session reflection skills as `session-wrap-up`, `session-pick-up`, and `session-recommend`.
- **feat:** `session-pick-up` gains a Phase 3 write step. It can save cards into the vault through `format-note`, gated by one `AskUserQuestion` approval.

## 1.0.3 — 2026-09-26

- **fix:** format-note accepts a bold claim inside a quote or callout (`> **claim**`, `> [!danger] **claim**`).
- **fix:** format-note no longer asks a map directly in a type folder to be renamed, matching migrate-notes 1.0.1.
- **feat:** `Sources:` is optional for concept and takeaway notes. `Related:` stays required.
- **feat:** a literature note can name its source with `> Link: <url>`, `> Source: <name>`, or a `Sources:` line. A literature note beside a `00__map__` note needs none, because the map names the series source.

## 1.0.2 — 2026-09-26

- **fix:** audit-tags ends a tag at the next `#`. A false tag glued to another one (`PR #1/#3`, `#1-#10`) is wrapped in backticks. 1.0.1 skipped 19 such tags in LifeOS.

## 1.0.1 — 2026-09-26

- **fix:** one tag must be a prefix covering at least half of the other for audit-tags to suggest a duplicate. The abbreviation rule is gone, because on real tags it only produced false merges (ci→containers, sre→serverless, clickhouse→cli).
- **fix:** migrate-notes keeps the name of a map note that sits directly in a type folder such as Permanent/. It no longer renames the note after that folder.

## 1.0.0 — 2026-09-26

- **feat:** rename note-visualizer to obsidian-kit. The visualize skill becomes format-note.
- **feat:** add create-excali and update-excali, moved from the LifeOS vault skill excalidraw-refine.
- **feat:** add migrate-notes and audit-tags.
- **feat:** absorb obsidian-markdown and obsidian-bases from kepano/obsidian-skills (MIT).
- **feat:** add a SessionStart primer for the obsidian CLI and defuddle.

## 0.2.1 - 2026-09-24

- **fix:** the PostToolUse reminder returns `additionalContext`, so it reaches Claude. It used `systemMessage`, which only the user sees, so the reminder never steered the model.
- **fix:** the reminder fires only for Markdown files under a `Zettelkasten/` folder. Before, it fired on every Markdown edit in every project, including READMEs and CHANGELOGs.

## 0.2.0 - 2026-09-20

- **feat:** add a `PostToolUse` hook (`hooks/hooks.json` + `hooks/remind-visualize.py`) that reminds Claude to apply the visualize principle on any markdown edit, in any project. Replaces the plugin's earlier "no hooks" design.
- **feat:** add a sequence-diagram style to the visual-patterns reference, for flows with 3+ participants trading ordered messages. Includes its own line and width budget.

## 0.1.1 - 2026-09-19

- **fix:** rewrite the visualize skill's prose to clear the simple-english linter. No content or meaning changed, only sentence shape.

## 0.1.0 — 2026-08-16

- **feat:** initial release, a `visualize` skill with inline and batch modes
- **feat:** visual-patterns reference codifying concept-shape → diagram-type mapping, callout rules, and one-screen budget constraints
- **feat:** model-invoked proactive triggering on Zettelkasten/ note writes
