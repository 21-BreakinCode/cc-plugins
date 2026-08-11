# hh

> Cross-context handover docs, LifeOS as the source of truth

Bridges your Obsidian LifeOS vault and each repo through a ./handover symlink, so handover documents survive context switches and stay visible to editors, grep, Obsidian, and Claude alike. Includes a daily vault-wide wrap-up state machine. Requires `HH_LIFEOS_ROOT` to point at your vault — the plugin never guesses a path.

## Install

```bash
claude plugin install hh@21-breakincode
```

## Commands

- **`/hh:init-org`** — Scaffold handover_handler__initiation.md for the current ORG in $LifeOS/01Project/$ORG/. One-time per ORG.
- **`/hh:init-service`** — Per-repo setup. Adds the current repo to the service mapping table and creates the ./handover symlink into LifeOS.
- **`/hh:new`** — Create a well-formed handover document under ./handover/ (= LifeOS via symlink) seeded from the current conversation context.
- **`/hh:wrap-up`** — Vault-wide daily wrap-up. Discovers active handovers, batches user decisions, executes archives/updates/suspensions in parallel. Replaces /op:wrap-up-today.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `HH_LIFEOS_ROOT` | `(required — no default)` | Absolute path to your LifeOS vault: the folder containing `01Project/`. **Required** — every command stops with setup guidance if it is unset or wrong, rather than falling back to a path that may not exist. Set it once in `~/.zshrc`: `export HH_LIFEOS_ROOT="$HOME/Projects/LifeOS"`. Find yours with `find "$HOME" -maxdepth 4 -type d -name '01Project'`. Quote the value if the path contains spaces. |
| `CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP` | `0` | When `1`, the Stop hook offers `/hh:new` after a wrap-up session (requires a working `./handover` symlink). |
| `HH_ARCHIVE_ROOT` | `$HH_LIFEOS_ROOT/04Archive` | Where `/hh:wrap-up` writes archived handovers. Defaults to `04Archive/` inside the resolved vault. Quote the value if the path contains spaces. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
