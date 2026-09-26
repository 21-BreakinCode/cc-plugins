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
