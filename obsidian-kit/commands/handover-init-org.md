---
description: "Scaffold handover_handler__initiation.md for the current ORG in $LifeOS/01Project/$ORG/. One-time per ORG."
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion"]
---

# /obsidian-kit:handover-init-org

One-time setup per ORG. Creates `handover_handler__initiation.md` in `$LifeOS/01Project/$ORG/`. Safe to re-run. If already initialized, it does nothing.

## Vault location

```bash
VAULT=$(python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/scripts')
from pathlib import Path
from common.vault import VaultConfigError, resolve_via_handover
try:
    print(resolve_via_handover(Path.cwd()))
except VaultConfigError as error:
    print(error, file=sys.stderr); sys.exit(3)
") || exit 3
export LIFEOS_ROOT="$VAULT"
```
**If this exits 3**, relay the stderr message to the user verbatim and stop. Do not guess a vault path.

## Flow

### Phase 1 — Verify 01Project reachable

```bash
[ -d "$VAULT/01Project" ] || { echo "01Project not reachable at $VAULT/01Project" >&2; exit 3; }
```

If unreachable, print the message and stop. Tell the user to check iCloud sync.

### Phase 2 — Resolve ORG

Run `bash ${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh` from the current working directory.

- **Exit 0 (org printed):** use that org name. Tell the user "Detected org: $ORG".
- **Exit 1 (no match):** list directories under `$VAULT/01Project/` (excluding `RawHandover/`), then `AskUserQuestion`:
  - `question`: "Which ORG is this initiation for?"
  - `options`: one per existing directory, plus "New ORG (enter name)"
- **Exit 3 (vault unreachable):** stop (already handled in Phase 1, but be defensive).

If the user picks "New ORG", follow up via `AskUserQuestion` with a free-form question for the ORG name. Use a single option whose label is "Continue".

### Phase 3 — Check existing initiation.md

```bash
INIT="$VAULT/01Project/$ORG/handover_handler__initiation.md"
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

If the user said yes:

```bash
mkdir -p "$VAULT/01Project/$ORG"
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
  2. Run /obsidian-kit:handover-init-service from each repo to populate the Service Mapping table.
```

## Non-negotiable rules

- Never overwrite an existing `handover_handler__initiation.md`. Always check first.
- Always use `${CLAUDE_PLUGIN_ROOT}/lib/initiation-template.md` as the source. Do not inline the template. Keep it editable in one place.
- Always check with the user via `AskUserQuestion` before writing.
