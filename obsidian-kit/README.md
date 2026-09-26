# obsidian-kit

> One plugin for the vault: draw, format, tag

Five commands. create-excali and update-excali build Excalidraw drawings through ExcalidrawAutomate, lint the geometry, and review the real PNG render. format-note writes and checks notes by their note-type (map, concept, takeaway, literature, fleeting) and keeps the ASCII-diagram and callout rules of the old visualize skill. migrate-notes sets note-type across a vault and renames map notes, as one approved plan. audit-tags finds false, duplicate, typo, and off-taxonomy tags and applies one approved rename plan with backups. A SessionStart hook primes Claude to treat the obsidian CLI as the source of truth. Vault opinions live in the vault file .obsidian-kit.json. No cross-plugin deps.

## Install

```bash
claude plugin install obsidian-kit@21-breakincode
```

## Skills

Invoke one directly as `/obsidian-kit:<skill>`, or let it activate automatically when relevant.

- **`create-excali`** — Create a new Obsidian Excalidraw drawing in the vault house style.
- **`format-note`** — Write or check Obsidian notes by note-type (map, concept, takeaway, literature, fleeting).
- **`migrate-notes`** — One-time vault migration to set note-type and rename map notes by plan approval.
- **`obsidian-bases`** — Create and edit Obsidian Bases (.base files) with views, filters, formulas, and summaries.
- **`obsidian-markdown`** — Create and edit Obsidian Flavored Markdown with wikilinks, embeds, callouts, properties, and other Obsidian-specific syntax.
- **`update-excali`** — Refine an existing Obsidian Excalidraw drawing into the vault house style.

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
