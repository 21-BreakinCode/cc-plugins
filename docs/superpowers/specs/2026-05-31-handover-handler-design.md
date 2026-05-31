# handover-handler Plugin Design Spec

**Date:** 2026-05-31
**Status:** Draft
**Plugin folder:** `handover-handler/`
**Command namespace:** `hh` (set via `"name": "hh"` in `plugin.json`)

## Overview

A Claude Code plugin that makes LifeOS (an iCloud-synced Obsidian vault) the single source of truth for cross-repo handover documents. Each repo gets a `./handover/` symlink pointing into LifeOS, so editors, grep, Obsidian, and Claude all see the same files. The plugin owns four commands covering ORG setup, per-repo service setup, new-handover authoring, and the daily wrap-up state machine. It subsumes the existing user-level `/op:wrap-up-today` command.

The goal is to reduce context-switching cost: write down "where I left off" once, in a canonical location, and pick it up from any repo or machine without hunting through git branches or scratch files.

## Design Principles

- **LifeOS is canonical.** No handover state lives only in a repo. Symlinks make the repo a view, not a store.
- **Obsidian-native data.** Frontmatter for properties Obsidian renders well; Markdown tables for structured lists. Avoid YAML where Obsidian renders poorly.
- **Fewest commands that fit the workflow.** Four commands cover org init, service init, new handover, and wrap-up. No `pickup`, no `doctor`, no `follow-up` command — those collapse into existing ones or just "read the file."
- **Inline prompts over silent assumptions.** When org/service can't be resolved, `AskUserQuestion` immediately — never guess.
- **Mac-only is fine.** Symlinks, iCloud paths, `gh` CLI are all assumed available. No cross-platform layer.

## Plugin Structure

```
handover-handler/
├── .claude-plugin/
│   └── plugin.json                 # name: "hh" → namespace /hh:*
├── commands/
│   ├── init-org.md                 # /hh:init-org
│   ├── init-service.md             # /hh:init-service
│   ├── new.md                      # /hh:new
│   └── wrap-up.md                  # /hh:wrap-up (replaces /op:wrap-up-today)
├── hooks/
│   ├── hooks.json                  # Stop hook registration
│   └── stop-offer-new.sh           # Offer /hh:new after a wrap-up session
├── lib/
│   ├── resolve-org.sh              # cwd → org name
│   ├── resolve-service.sh          # cwd + initiation.md → app_name + lifeos_subpath
│   ├── parse-mapping.sh            # Markdown table → records (app_name|repo_path|lifeos_subpath)
│   ├── ensure-symlink.sh           # Idempotent ln -sf with dangling/conflict checks
│   └── initiation-template.md      # Template scaffolded by /hh:init-org
└── README.md
```

No agents, no skills. The plugin shape mirrors `session-learner/`: thin shell helpers under `lib/`, behavior driven by markdown command prompts.

## Vault Layout (assumed)

```
$LifeOS = $HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS

$LifeOS/
└── 01Project/
    ├── Appier/
    │   ├── handover_handler__initiation.md   # written by /hh:init-org
    │   └── Services/
    │       ├── CreativeStudio/
    │       │   └── handover/                  # symlink target for the repo
    │       └── CrPerf2/
    │           └── handover/
    ├── BustDice/
    │   ├── handover_handler__initiation.md
    │   └── Services/
    │       └── <app>/handover/
    └── Ryocal/
        └── handover_handler__initiation.md
```

All orgs use `Services/$APP_NAME/`. BustDice's existing `Devops/` folder is treated as not-yet-migrated; the plugin warns but doesn't auto-migrate.

## Commands

### `/hh:init-org`

**Scope:** per ORG, one-time.

**Behavior:**

1. Resolve current org via `lib/resolve-org.sh`. If indeterminate, `AskUserQuestion` with the list of org subdirectories under `$LifeOS/01Project/`.
2. Check `$LifeOS/01Project/$ORG/handover_handler__initiation.md`.
   - If exists → print "already initialized" and exit.
   - If missing → confirm via `AskUserQuestion` ("Scaffold initiation.md for $ORG?"). On yes, write `lib/initiation-template.md` with `$ORG` substituted, then echo path and remind the user to fill the clone block and (if relevant) seed the service-mapping table.

**Template shape** (see Data Model section below for the parsed schema):

```markdown
---
org: <ORG>
workspace_root: $HOME/Projects/<ORG>
github_orgs: []
tags: [handover-handler-init]
---

# <ORG> — handover_handler initiation

## Service Mapping

| app_name | repo_path | lifeos_subpath |
| --- | --- | --- |

## One Prompt Clone

`​``bash
# fill in: gh repo clone loop for github_orgs above
`​``

## Notes
```

### `/hh:init-service`

**Scope:** per repo, one-time.

**Behavior:**

1. Resolve org from `cwd` via git remote + path heuristics (`lib/resolve-org.sh`).
2. Load `$LifeOS/01Project/$ORG/handover_handler__initiation.md`. If missing, instruct user to run `/hh:init-org` first and stop.
3. Parse the `## Service Mapping` table via `lib/parse-mapping.sh`.
4. Resolve cwd via `lib/resolve-service.sh` (which applies the exact-or-descendant match policy described in **Service Resolution** below).
   - **Match found:** use that row's `app_name` and `lifeos_subpath`.
   - **No match:** `AskUserQuestion` (batched, 2 questions):
     - Q1 `app_name?` — propose a slug from the cwd basename + free-form option.
     - Q2 `lifeos_subpath?` — propose `Services/<app_name>` as default + free-form option.
     - On answer, append a new row to the mapping table (preserve column alignment).
5. `mkdir -p $LifeOS/01Project/$ORG/$LIFEOS_SUBPATH/handover/`.
6. Run `lib/ensure-symlink.sh ./handover $LifeOS/01Project/$ORG/$LIFEOS_SUBPATH/handover`:
   - If `./handover` already exists as a symlink pointing to the right target → no-op.
   - If exists as a symlink to a different target → `AskUserQuestion` to confirm overwrite.
   - If exists as a regular directory with content → STOP and report (do not destroy data).
   - Otherwise → `ln -sf` the target.
7. Append `handover/` to `.gitignore` if missing (after a separating blank line if file is non-empty).
8. Report: org, app_name, symlink target, gitignore status.

### `/hh:new <topic>`

**Scope:** per task.

**Behavior:**

1. Resolve org + app from `cwd` (re-run resolve-org + parse-mapping). If unresolved → instruct user to run `/hh:init-service` and stop.
2. Verify `./handover/` exists as a symlink and target is reachable. If dangling (LifeOS unmounted), error with a clear message.
3. Build filename: `<prefix>__<YYYY-MM-DD>-<slug>.md`.
   - `<prefix>` = `app_name` converted camelCase/PascalCase → kebab-case (e.g., `CreativeStudio` → `creative-studio`, `CrPerf2` → `cr-perf-2`, `BustDice` → `bust-dice`).
   - `<slug>` = topic argument kebab-cased, truncated to 60 chars.
4. Seed file with frontmatter:
   ```yaml
   ---
   created: <YYYY-MM-DD>
   project: <app_name>
   status: open
   tags:
     - handover
     - <app_name kebab>
   ---
   ```
5. Below frontmatter, add `## TL;DR`, `## Context`, `## What's next` headings. The `## Context` body is seeded from the orchestrator's summary of the current conversation (Claude writes a 3–6 line summary referencing relevant file paths and decisions so far). Empty headings if no conversation context yet.
6. Write to `./handover/<filename>` (which lands in LifeOS via the symlink).
7. Echo the absolute LifeOS path and the relative repo path.

### `/hh:wrap-up`

**Scope:** vault-wide. Replaces `/op:wrap-up-today`.

**Behavior:** mirrors the existing `/op:wrap-up-today` 5-phase flow, with two changes:

- **State set is reduced** to: `active`, `active-update`, `suspended`, `done`, `superseded`, `Other`. Drops `decided` and `planned` — any historical archived files with those statuses stay as-is; new wrap-ups don't produce them.
- **`suspended` added** as an active-side state: appends a `## Suspended` heading with today's date and an optional reason, but the file keeps `handover` tag and does NOT get `archive`. The frontmatter `status:` field gets set to `suspended`.

Phase summary:

1. **Discover:** find files under `$LifeOS` where frontmatter tags contain `handover` and not `archive`.
2. **Analyze:** one subagent per file, in parallel (single message). Each reports topic, project prefix, visible state, suggested action, suggested archive filename, and incoming wikilink classification (living vs historical). Subagent prompt is identical in spirit to `/op:wrap-up-today` Phase 2 but with the reduced state set.
3. **Batched query:** print a compact table; ask `AskUserQuestion` for each file in a single batched call. Options: `Active — no change`, `Active — append update`, `Active — suspend`, `Archive: done`, `Archive: superseded`, `Other`.
4. **Execute:** parallel subagents for archive set + update set + suspend set. Custom set handled inline by the orchestrator. Wikilink rewrites in living docs only (skip `02-Area/Journal/**` and dated handovers in `handover/`/`meeting/`).
5. **Report:** archived list with new paths, updates appended list, suspended list, untouched list, wikilink-rewrite counts.

Non-negotiable rules (carried over from `/op:wrap-up-today`):

- Naming: `<prefix>__<status>-[date-]<topic>.md`, status ∈ {`done`, `superseded`}. `suspended` files keep their original name.
- Add `archive` tag, never replace existing tags.
- Don't edit historical records (journals, dated handovers).
- No generic aliases on archived files.
- Update wikilinks in living docs only.
- Active updates only append dated subsections; never modify frontmatter or tags.
- Stop and ask when project prefix is ambiguous or `superseded by` reference needs naming.

## Data Model: `handover_handler__initiation.md`

**Frontmatter (parsed as YAML):**

| Field | Type | Notes |
|---|---|---|
| `org` | string | Matches the parent directory under `01Project/`. |
| `workspace_root` | string | Absolute path on local disk (may use `$HOME`). |
| `github_orgs` | list of strings | Used by the clone block. |
| `tags` | list | Always includes `handover-handler-init`. |

**Body sections (parsed by convention):**

- `## Service Mapping` — Markdown table with columns `app_name`, `repo_path`, `lifeos_subpath`. Header row + separator row mandatory.
- `## One Prompt Clone` — first fenced bash block under this heading is the canonical clone script.
- `## Notes` — free-form, not parsed.

**`lib/parse-mapping.sh` contract:**

- Input: path to initiation.md.
- Output (stdout, one record per line, pipe-separated): `<app_name>|<repo_path>|<lifeos_subpath>`. Whitespace trimmed. `$HOME` and `$LifeOS` left literal — caller expands.
- Errors to stderr; nonzero exit if the table is malformed (missing header, fewer than 3 columns, etc.).

## State Machine

```
                ┌──────────┐
                │  active  │  ← new handovers default here
                └────┬─────┘
      ┌──────────────┼──────────────┬──────────────┐
      ▼              ▼              ▼              ▼
 active-update   suspended        done        superseded
 (append dated   (status:        (archive    (archive +
  note, stay      suspended,     as          name replacing
  tagged          stays tagged   completed,  doc; rewrite
  handover)       handover, no   YYYY-MM-DD  living wikilinks)
                  archive tag)   in filename)
```

- `Other` is an escape hatch — orchestrator handles inline with explicit user confirmation; never spawned to subagent.
- From `suspended`, the next wrap-up can transition to `active` (just append update) or to `done`/`superseded`.

## Symlink Contract

- `./handover` in a repo is **always** a symlink whose target is `$LifeOS/01Project/$ORG/<lifeos_subpath>/handover/` (a directory).
- The symlink is created by `/hh:init-service` and assumed stable for the life of the repo.
- **Files** moving between `active` and `04-Archive/` change what's visible inside the symlink — the symlink itself is unchanged.
- The plugin never creates per-file symlinks. There is no "archive view" symlink inside the repo by default.
- `ensure-symlink.sh` is idempotent: re-running `/hh:init-service` is safe.
- Dangling symlink detection: every command that reads/writes `./handover/` first checks `readlink -e ./handover` succeeds; on failure, reports "LifeOS target unreachable — check iCloud sync" and stops.

## Hook: `stop-offer-new`

**Event:** `Stop` (Claude has finished responding to the user).

**Purpose:** after a session that ran `/hh:wrap-up`, offer to start a new handover for the day.

**Trigger logic** (in `stop-offer-new.sh`):

1. Check env var `CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP`. If unset or `0`, exit 0 silently (default = disabled until user opts in).
2. Read the transcript path from the Stop hook's stdin JSON payload.
3. Tail the last ~200 lines of the transcript; look for `/hh:wrap-up` invocation in user prompts AND a wrap-up report in assistant output (heuristic: a line matching `Wrap-up complete`).
4. If found, emit a `hookSpecificOutput.additionalContext` JSON payload reading approximately:
   > Reminder: `/hh:wrap-up` just ran. Ask the user via `AskUserQuestion` whether they'd like to start a new handover with `/hh:new` for any new threads of work surfaced by the wrap-up. Single question, two options (`Yes, /hh:new <topic>` / `No, done for today`).
5. Set `decision: undefined` (informational only, do not block).

**Configuration:**

- Env var: `CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP` (`1` = enabled, anything else = disabled).
- Default: **disabled**. Documented in README's "Plugin Configuration" section.
- Timeout: 5 seconds — the hook is a small bash script with one transcript scan; if it stalls, skip.

**hooks.json:**

```json
{
  "description": "After a wrap-up, offer to start a new handover.",
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash '${CLAUDE_PLUGIN_ROOT}/hooks/stop-offer-new.sh'",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Org Resolution (`lib/resolve-org.sh`)

Input: current working directory.

Algorithm:

1. **Git remote match.** Run `git remote get-url origin` (if inside a git repo). Match the host/path against each org's `github_orgs` list across all `$LifeOS/01Project/*/handover_handler__initiation.md` files. First match wins.
2. **Path prefix match.** If step 1 fails, walk up from cwd looking for a parent directory whose name matches an `org` field from any initiation.md.
3. **`AskUserQuestion` fallback.** If both fail, present the list of orgs (subdirs of `$LifeOS/01Project/` excluding `RawHandover/`).

Output: org name to stdout. Nonzero exit if the user cancels the fallback.

## Service Resolution (`lib/resolve-service.sh`)

Input: cwd, org.

Algorithm:

1. Load `$LifeOS/01Project/$ORG/handover_handler__initiation.md`. Error if missing (caller is expected to direct user to `/hh:init-org`).
2. Run `parse-mapping.sh`.
3. Match cwd against the `repo_path` column. Expansion: `$HOME` and `$LifeOS` expand to env equivalents.
4. Match policy: exact match preferred; if cwd is a descendant of a `repo_path`, that counts as a match (so subdirs of a repo still resolve correctly).

Output: `<app_name>|<lifeos_subpath>` to stdout. Nonzero exit if no match (caller asks the user via `AskUserQuestion`).

## Edge Cases & Prompts

| Situation | Behavior |
|---|---|
| `$LifeOS` path unreachable (iCloud not mounted) | All commands stop early with: "LifeOS not reachable at $LifeOS — check iCloud sync." |
| `cwd` is outside any known repo, no git remote | `/hh:init-service` runs org-resolution fallback; if org chosen, asks for `app_name` + `lifeos_subpath` via `AskUserQuestion`. |
| `./handover` already exists as a regular directory with content | `/hh:init-service` STOPS with: "`./handover/` exists with content — move files manually before re-running." Never destroys data. |
| `./handover` is a symlink to a different LifeOS target | `AskUserQuestion`: keep existing / overwrite / abort. |
| `/hh:new` called before `/hh:init-service` | Error: "Run `/hh:init-service` first — no symlink at ./handover." |
| Service mapping row has duplicate `app_name` | Plugin uses the first match. Warns in stderr that table has duplicates. |
| BustDice's `Devops/` (non-`Services/`) layout | `/hh:init-service` warns: "BustDice currently uses Devops/ instead of Services/. Consider migrating, or set `lifeos_subpath: Devops/<app>` explicitly." Does not auto-migrate. |
| `/hh:wrap-up` finds 0 active handovers | Print "No active handovers — nothing to wrap up." Exit. Stop hook still fires but its scan won't find a `Wrap-up complete` line, so no follow-up offer. |

## Out of Scope

- Cross-platform support (Windows, Linux).
- Migrating BustDice's `Devops/` layout to `Services/` (user does manually).
- Cloning repos (the "one prompt clone" block is user-run, plugin doesn't execute it).
- Obsidian plugin development (no plugin installed inside the vault).
- Notification/Slack integration on wrap-up completion.
- Conflict resolution if two machines edit the same handover simultaneously (iCloud's responsibility).
- A `pickup` / resume command — reading the file in Obsidian or via Claude is sufficient.
- Auto-spawning a child handover on `follow_up` — user runs `/hh:new` manually after archiving.

## Migration from `/op:wrap-up-today`

1. Implement `/hh:wrap-up` to parity with current `/op:wrap-up-today` behavior except for the state-set change.
2. Run both in parallel for one or two daily cycles to verify equivalence on real data.
3. Once verified, delete `~/.claude/commands/op/wrap-up-today.md`.
4. Existing archived files using `decided`/`planned` statuses are not migrated. The state machine just doesn't produce new ones.

## Open Questions

- Should `/hh:new` accept an optional `--parent <path>` flag to seed a wikilink to a previously-archived handover (the manual "follow-up" pattern)? Defer until needed.
- Should `lib/parse-mapping.sh` be a bash script (using `awk`) or a tiny Python script for robustness? Default: bash + awk, swap to Python only if table parsing turns out brittle.

## Testing Strategy

Manual smoke tests per command on real LifeOS state. No automated test harness in v1.

- `/hh:init-org` on Ryocal (no initiation.md exists) → file scaffolded.
- `/hh:init-org` on Appier (exists) → no-op.
- `/hh:init-service` on an Appier repo not in mapping → mapping updated, symlink created.
- `/hh:init-service` re-run on same repo → idempotent.
- `/hh:new "test topic"` → file appears under correct service folder.
- `/hh:wrap-up` on a known set of test handovers → archive + update + suspend all execute, wikilinks rewritten in living docs only.
- Stop hook fires only when `CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1` AND wrap-up ran.
