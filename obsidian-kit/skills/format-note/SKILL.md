---
name: format-note
description: Write or check Obsidian notes by note-type (map, concept, takeaway, literature, fleeting). Each type keeps one fixed format, with compact ASCII diagrams and callouts that make notes scannable. When creating or editing a note inside the vault's noteFormatFolders, such as Zettelkasten notes, use this proactively. Also trigger on "format note", "check note format", "visualize", "add diagrams", "加圖", "refine notes", or "make scannable".
argument-hint: "[vault-relative path or folder]"
---

# format-note

Read `${CLAUDE_PLUGIN_ROOT}/references/note-formats.md` and
`${CLAUDE_PLUGIN_ROOT}/references/visual-patterns.md` first.

## Inline mode: while writing a note

1. Pick the note-type. The folder rules are in `.obsidian-kit.json` (`typeFolders`). A
   `00__map__` name is a map. A `NN__` name next to a map is a takeaway.
2. Write the note in that type's format and set `note-type:` in frontmatter.
3. Take tags only from the taxonomy file's `## Allowed` table. If none fits, propose a
   new tag and ask the user. Never add a tag silently.
4. For map, concept, and takeaway notes, apply visual-patterns: diagram before prose,
   at most one callout, and skip diagrams for flat or linear content.

## Check mode: `/obsidian-kit:format-note <path|folder>`

1. From the vault root, run
   `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/notes/check_note.py "<path|folder>"`.
2. Show the failing notes grouped by rule.
3. Propose the fixes for each note. Write only after the user approves.
4. A note with an unset note-type needs `/obsidian-kit:migrate-notes` first.
