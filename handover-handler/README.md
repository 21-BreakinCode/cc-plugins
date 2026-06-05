# handover-handler

Bridge LifeOS ↔ each repo for cross-context handover documents. Subsumes `/op:wrap-up-today`.

## Why

LifeOS (Obsidian vault, iCloud-synced) is the source of truth for project handovers. Each repo gets a `./handover/` symlink into LifeOS so editors, grep, Obsidian, and Claude all see the same files. When you context-switch, the handover survives the switch.

## Commands

| Command | When to use |
|---|---|
| `/hh:init-org` | Once per org. Scaffolds `handover_handler__initiation.md` in `$LifeOS/01Project/$ORG/`. |
| `/hh:init-service` | Once per repo. Adds the repo to the service mapping table and creates the `./handover/` symlink. |
| `/hh:new <topic>` | Mid-task. Creates a well-formed handover under `./handover/`. |
| `/hh:wrap-up` | Daily. Vault-wide state-machine pass. States: `active`, `active-update`, `suspended`, `done`, `superseded`. |

## Plugin Configuration (env vars in `~/.zshrc`)

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP` | `0` | When `1`, after a session that ran `/hh:wrap-up`, the Stop hook reminds Claude to offer `/hh:new`. Also requires the cwd to have a working `./handover` symlink — otherwise the hook is a no-op. |
| `HH_ARCHIVE_ROOT` | `"$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/04Archive"` | Root folder where `/hh:wrap-up` writes archived handovers. Files land under `$HH_ARCHIVE_ROOT/<ORG>/<filename>.md`. Always quote the value (contains `$HOME` and spaces). |

## Vault Layout

```
$LifeOS/01Project/$ORG/
├── handover_handler__initiation.md   # frontmatter + Service Mapping table + clone block
└── Services/$APP_NAME/handover/      # symlink target for the repo's ./handover/
```

## Spec & Design

See `docs/superpowers/specs/2026-05-31-handover-handler-design.md` in the cc-plugins repo.
