# apple-kit

> Apple Notes and Apple Health for Claude Code

apple-notes creates, reads, edits, moves, and deletes Apple Notes through the notes command of macnotesapp. It selects notes by id, reads a note before it changes it, and asks for approval before every change, in a terminal or over a chat bot. apple-health syncs weight and body fat from an iPhone Shortcut export into a Markdown body log, because macOS cannot read Apple Health. The script uses the Python standard library only, adds rows, fills empty cells, and never changes a value. Vault paths live in the vault file .apple-kit.json. No cross-plugin deps.

## Install

```bash
claude plugin install apple-kit@21-breakincode
```

## Skills

Invoke one directly as `/apple-kit:<skill>`, or let it activate automatically when relevant.

- **`apple-health`** — Sync Apple Health weight and body fat into the vault's body log, or set up the iPhone export that feeds it.

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
