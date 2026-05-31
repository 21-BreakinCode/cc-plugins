---
description: "Scaffold handover_handler__initiation.md for the current ORG in $LifeOS/01Project/$ORG/. One-time per ORG."
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion"]
---

# /hh:init-org

One-time setup per ORG. Creates `handover_handler__initiation.md` in `$LifeOS/01Project/$ORG/`. Safe to re-run — no-ops if already initialized.

## Vault location

```bash
LIFEOS="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
```

## Flow

### Phase 1 — Verify LifeOS reachable

```bash
[ -d "$LIFEOS/01Project" ] || { echo "LifeOS not reachable at $LIFEOS/01Project" >&2; exit 3; }
```

If unreachable, print the message and stop. Tell the user to check iCloud sync.

### Phase 2 — Resolve ORG

Run `bash ${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh` from the current working directory.

- **Exit 0 (org printed):** use that org name. Tell the user "Detected org: $ORG".
- **Exit 1 (no match):** list directories under `$LIFEOS/01Project/` (excluding `RawHandover/`), then `AskUserQuestion`:
  - `question`: "Which ORG should this initiation be for?"
  - `options`: one per existing directory, plus "New ORG (enter name)"
- **Exit 3 (LifeOS unreachable):** stop (already handled in Phase 1, but be defensive).

If the user picks "New ORG", follow up via `AskUserQuestion` with a free-form question for the ORG name (use a single option whose label is "Continue").

### Phase 3 — Check existing initiation.md

```bash
INIT="$LIFEOS/01Project/$ORG/handover_handler__initiation.md"
```

- If `$INIT` exists: report "Already initialized at $INIT" and stop.
- Otherwise continue.

### Phase 4 — Confirm with user

`AskUserQuestion`:
- `question`: "Scaffold initiation.md for $ORG?"
- `options`:
  - "Yes, scaffold the template"
  - "No, abort"

### Phase 5 — Write template

If confirmed:

```bash
mkdir -p "$LIFEOS/01Project/$ORG"
sed "s/__ORG__/$ORG/g" "${CLAUDE_PLUGIN_ROOT}/lib/initiation-template.md" > "$INIT"
```

### Phase 6 — Report

Print:
```
Scaffolded: $INIT

Next steps:
  1. Edit the file in Obsidian. Fill in:
     - github_orgs (frontmatter)
     - One Prompt Clone (bash block)
  2. Run /hh:init-service from each repo to populate the Service Mapping table.
```

## Non-negotiable rules

- Never overwrite an existing `handover_handler__initiation.md`. Always check first.
- Always use `${CLAUDE_PLUGIN_ROOT}/lib/initiation-template.md` as the source (do not inline the template — keep it editable in one place).
- Always confirm via `AskUserQuestion` before writing.
