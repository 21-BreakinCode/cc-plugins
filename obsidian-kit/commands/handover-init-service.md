---
description: "Per-repo setup. Adds the current repo to the service mapping table and creates the ./handover symlink into LifeOS."
allowed-tools: ["Bash", "Read", "Write", "Edit", "AskUserQuestion"]
---

# /obsidian-kit:handover-init-service

One-time per repo. It resolves the current org, and finds or appends the service mapping row for this repo. If the LifeOS handover folder is missing, it creates one. It symlinks `./handover` to that folder, and checks that `.gitignore` covers it.

## Vault location

### Phase 0 — Locate the vault

Try the resolver first:

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
")
EXIT=$?
```

If `$EXIT` is 0, run `export LIFEOS_ROOT="$VAULT"` and skip to Phase 1.

If it fails because `./handover` does not exist yet, ask
the user once with `AskUserQuestion`:

- `header`: `Vault`
- `question`: `Where is your Obsidian vault? (the folder containing 01Project/)`
- `options`: any path already in `.claude/settings.local.json`, plus `Other`

Write the answer to this repo's `.claude/settings.local.json` under
`env.OBSIDIAN_KIT_VAULT`, so the next run resolves without asking. Check that the
path holds `.obsidian/` and `01Project/` before writing it. Then set
`VAULT="$OBSIDIAN_KIT_VAULT"` and `export LIFEOS_ROOT="$VAULT"`, and continue.

If it fails for any other reason, relay the stderr message to the user verbatim and stop.

## Flow

### Phase 1 — Resolve ORG

```bash
ORG=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh") || {
    rc=$?
    [ "$rc" -eq 3 ] && { echo "Vault not reachable — relay the Phase 0 guidance above and stop."; exit 3; }
    ORG=""
}
```

- If `$ORG` is empty: tell the user "Did not auto-detect an ORG. If this is a new ORG, run /obsidian-kit:handover-init-org first. Otherwise, use AskUserQuestion to pick from existing ORGs." Then `AskUserQuestion` listing existing ORG dirs under `$VAULT/01Project/`. If user picks one with no initiation.md, stop and instruct them to run `/obsidian-kit:handover-init-org $ORG` first.

Report: "Org: $ORG".

### Phase 2 — Verify initiation.md exists

```bash
INIT="$VAULT/01Project/$ORG/handover_handler__initiation.md"
[ -f "$INIT" ] || { echo "Run /obsidian-kit:handover-init-org first — $INIT missing"; exit 1; }
```

### Phase 3 — Resolve service mapping

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-service.sh" "$PWD" "$ORG") && EXIT=$? || EXIT=$?
```

- **Exit 0:** parse `app_name|lifeos_subpath` from `$RESULT`. Report "Mapped: $APP_NAME → $LIFEOS_SUBPATH" and skip to Phase 5.
- **Exit 1:** not mapped yet. Continue to Phase 4.
- **Exit 2 or 3:** report the error and stop.

### Phase 4 — Collect new mapping row values

Compute defaults:
- `DEFAULT_APP_NAME` = current directory name, used verbatim in kebab-case (for example, `creative-studio` → `creative-studio`, `bust-backend` → `bust-backend`). If the directory name is not already kebab-case, lowercase it and replace `_`, spaces, and camelCase boundaries with `-`.
- `DEFAULT_LIFEOS_SUBPATH` = `Services/$DEFAULT_APP_NAME`.

`AskUserQuestion` (batched, 2 questions in a single call). The Q2 default uses `$DEFAULT_APP_NAME`, not the user's Q1 answer, because batched questions resolve simultaneously:

1. `header: "app_name"`, `question: "App name for this repo?"`, options: `[$DEFAULT_APP_NAME]`, `[Other...]`
2. `header: "lifeos path"`, `question: "LifeOS subpath under $ORG/?"`, options: `[Services/$DEFAULT_APP_NAME]`, `[Other...]`

For "Other..." answers, follow up with a free-form `AskUserQuestion`. If the user picked a non-default `app_name` in Q1 but accepted the default Q2 (`Services/$DEFAULT_APP_NAME`), prompt one more time: "Use `Services/<app_name>` instead?" → adjust accordingly.

A new row for the `## Service Mapping` table in `$INIT` looks like:

```bash
# Compute a row like:
#   | new-app         | $HOME/Projects/Appier/appier/new-app      | Services/new-app          |
# Use a Python heredoc to align columns to existing widths if reliable;
# otherwise just append with single-space padding (Obsidian tables tolerate it).
```

### Phase 4a — Confirm with user

`AskUserQuestion`:
- `question`: "Append this row to $INIT and create $VAULT/01Project/$ORG/$LIFEOS_SUBPATH/handover/?\n| $APP_NAME | $PWD | $LIFEOS_SUBPATH |"
- `options`:
  - "Yes, write it"
  - "No, abort"

If the user picks "No, abort", stop. Do not write the row and do not run Phase 5.

### Phase 5 — Write the row and create the LifeOS handover folder

If the user said yes:

Use `Edit` to append the new row computed in Phase 4 to `$INIT`. If the table is empty, append it after the separator row. Otherwise, append it after the last existing data row. Preserve all other content.

```bash
mkdir -p "$VAULT/01Project/$ORG/$LIFEOS_SUBPATH/handover"
```

### Phase 6 — Symlink ./handover

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ensure-symlink.sh" \
    "$PWD/handover" \
    "$VAULT/01Project/$ORG/$LIFEOS_SUBPATH/handover"
EXIT=$?
```

Handle exit codes:
- 0: proceed.
- 1: `./handover/` exists with content. Stop and report. Do not destroy data.
- 4: symlink exists pointing elsewhere. `AskUserQuestion`: `[Keep existing]`, `[Overwrite (force)]`, `[Abort]`. If overwrite, re-run with `force`.

### Phase 7 — Ensure .gitignore

If `.gitignore` does not exist, create it with `handover/\n`.

Else, check whether `handover/` is already present (any of: `^handover/?$`, with or without leading whitespace). If missing, append `handover/` on a new line (with a separating blank line if file ends mid-content).

### Phase 8 — Report

```
✓ Service initialized:
    ORG:            $ORG
    APP_NAME:       $APP_NAME
    LIFEOS path:    $VAULT/01Project/$ORG/$LIFEOS_SUBPATH/handover/
    Symlink:        $PWD/handover -> (above)
    .gitignore:     handover/ (added | already present)

Next: /obsidian-kit:handover-new <topic>
```

## Non-negotiable rules

- Never destroy a non-empty `./handover/` directory. If conflict, stop and ask the user.
- Service mapping rows are append-only via this command. Never rewrite existing rows.
- The .gitignore edit only adds `handover/`. It never removes or reorders existing lines.
- BustDice currently uses `Devops/` instead of `Services/`. If the user picks a non-`Services/` `lifeos_subpath`, warn but allow.
