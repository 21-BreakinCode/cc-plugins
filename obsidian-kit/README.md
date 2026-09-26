# obsidian-kit

> One plugin for the vault: draw, format, tag

create-excali and update-excali build Excalidraw drawings through ExcalidrawAutomate, lint the geometry, and review the real PNG render. format-note writes and checks notes by their note-type (map, concept, takeaway, literature, fleeting) and keeps the ASCII-diagram and callout rules of the old visualize skill. migrate-notes sets note-type across a vault and renames map notes, as one approved plan. audit-tags finds false, duplicate, typo, and off-taxonomy tags and applies one approved rename plan with backups. handover-new, handover-wrap-up, handover-init-org, and handover-init-service create and wrap up handover documents backed by the vault. session-wrap-up, session-pick-up, and session-recommend turn a working session into reflection take-aways and, after one approval, Zettelkasten cards in the vault. A dedicated skill writes and checks controlled Traditional Chinese inside the vault. A SessionStart hook primes Claude to treat the obsidian CLI as the source of truth. Vault opinions live in the vault file .obsidian-kit.json. No cross-plugin deps.

## Install

```bash
claude plugin install obsidian-kit@21-breakincode
```

## Commands

- **`/obsidian-kit:handover-init-org`** — Scaffold handover_handler__initiation.md for the current ORG in $LifeOS/01Project/$ORG/. One-time per ORG.
- **`/obsidian-kit:handover-init-service`** — Per-repo setup. Adds the current repo to the service mapping table and creates the ./handover symlink into LifeOS.
- **`/obsidian-kit:handover-new`** — Create a well-formed handover document under ./handover/ (= LifeOS via symlink) seeded from the current conversation context.
- **`/obsidian-kit:handover-wrap-up`** — Vault-wide daily wrap-up. Discovers active handovers, batches user decisions, executes archives/updates/suspensions in parallel. Replaces /op:wrap-up-today.

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
