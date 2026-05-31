---
description: "Per-repo setup. Adds the current repo to the service mapping table and creates the ./handover symlink into LifeOS."
allowed-tools: ["Bash", "Read", "Write", "Edit", "AskUserQuestion"]
---

# /hh:init-service

One-time per repo. Resolves the current org, finds (or appends) the service mapping row for this repo, creates the LifeOS handover folder if missing, symlinks `./handover` to it, and ensures `.gitignore` covers it.

## Vault location

```bash
LIFEOS="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
```

## Flow

### Phase 1 — Resolve ORG

```bash
ORG=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh") || {
    rc=$?
    [ "$rc" -eq 3 ] && { echo "LifeOS not reachable — check iCloud sync and re-run."; exit 3; }
    ORG=""
}
```

- If `$ORG` is empty: tell the user "Could not auto-detect ORG. Run /hh:init-org first if this is a new ORG, or use AskUserQuestion to pick from existing ORGs." Then `AskUserQuestion` listing existing ORG dirs under `$LIFEOS/01Project/`. If user picks one with no initiation.md, stop and instruct them to run `/hh:init-org $ORG` first.

Report: "Org: $ORG".

### Phase 2 — Verify initiation.md exists

```bash
INIT="$LIFEOS/01Project/$ORG/handover_handler__initiation.md"
[ -f "$INIT" ] || { echo "Run /hh:init-org first — $INIT missing"; exit 1; }
```

### Phase 3 — Resolve service mapping

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-service.sh" "$PWD" "$ORG") && EXIT=$? || EXIT=$?
```

- **Exit 0:** parse `app_name|lifeos_subpath` from `$RESULT`. Report "Mapped: $APP_NAME → $LIFEOS_SUBPATH" and skip to Phase 5.
- **Exit 1:** not mapped yet. Continue to Phase 4.
- **Exit 2 or 3:** report the error and stop.

### Phase 4 — Append new mapping row

Compute defaults:
- `DEFAULT_APP_NAME` = current directory name converted to PascalCase (e.g. `creative-studio` → `CreativeStudio`, `bust-backend` → `BustBackend`).
- `DEFAULT_LIFEOS_SUBPATH` = `Services/$DEFAULT_APP_NAME`.

`AskUserQuestion` (batched, 2 questions in a single call). The Q2 default uses `$DEFAULT_APP_NAME`, not the user's Q1 answer, because batched questions resolve simultaneously:

1. `header: "app_name"`, `question: "App name for this repo?"`, options: `[$DEFAULT_APP_NAME]`, `[Other...]`
2. `header: "lifeos path"`, `question: "LifeOS subpath under $ORG/?"`, options: `[Services/$DEFAULT_APP_NAME]`, `[Other...]`

For "Other..." answers, follow up with a free-form `AskUserQuestion`. If the user picked a non-default `app_name` in Q1 but accepted the default Q2 (`Services/$DEFAULT_APP_NAME`), prompt one more time: "Use `Services/<app_name>` instead?" → adjust accordingly.

Append a new row to the `## Service Mapping` table in `$INIT`:

```bash
# Compute a row like:
#   | NewApp          | $HOME/Projects/Appier/appier/new-app      | Services/NewApp           |
# Use a Python heredoc to align columns to existing widths if reliable;
# otherwise just append with single-space padding (Obsidian tables tolerate it).
```

Use `Edit` to append the new row after the last existing data row (or after the separator row if the table is empty). Preserve all other content.

### Phase 5 — Create LifeOS handover folder

```bash
mkdir -p "$LIFEOS/01Project/$ORG/$LIFEOS_SUBPATH/handover"
```

### Phase 6 — Symlink ./handover

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ensure-symlink.sh" \
    "$PWD/handover" \
    "$LIFEOS/01Project/$ORG/$LIFEOS_SUBPATH/handover"
EXIT=$?
```

Handle exit codes:
- 0 — proceed.
- 1 — `./handover/` exists with content. Stop and report; do not destroy data.
- 4 — symlink exists pointing elsewhere. `AskUserQuestion`: `[Keep existing]`, `[Overwrite — force]`, `[Abort]`. If overwrite, re-run with `force`.

### Phase 7 — Ensure .gitignore

If `.gitignore` does not exist, create it with `handover/\n`.

Else, check whether `handover/` is already present (any of: `^handover/?$`, with or without leading whitespace). If missing, append `handover/` on a new line (with a separating blank line if file ends mid-content).

### Phase 8 — Report

```
✓ Service initialized:
    ORG:            $ORG
    APP_NAME:       $APP_NAME
    LIFEOS path:    $LIFEOS/01Project/$ORG/$LIFEOS_SUBPATH/handover/
    Symlink:        $PWD/handover -> (above)
    .gitignore:     handover/ (added | already present)

Next: /hh:new <topic>
```

## Non-negotiable rules

- Never destroy a non-empty `./handover/` directory. If conflict, stop and ask the user.
- Service mapping rows are append-only via this command — never rewrite existing rows.
- The .gitignore edit only adds `handover/`. It never removes or reorders existing lines.
- BustDice currently uses `Devops/` instead of `Services/`. If the user picks a non-`Services/` `lifeos_subpath`, warn but allow.
