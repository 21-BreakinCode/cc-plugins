# obsidian-kit design

Date: 2026-09-26. Status: draft for review.

## Goal

One self-maintained plugin for working in an Obsidian vault with Claude Code.
It replaces three sources:

- `note-visualizer` 0.2.1 (this repo). The plugin directory is renamed.
- kepano's `obsidian` plugin 1.0.1 (installed from github.com/kepano/obsidian-skills).
  The useful parts are absorbed, then the plugin is uninstalled.
- The vault-local `excalidraw-refine` skill, scripts, and lint hook in LifeOS.

Success criteria:

1. `obsidian-kit` 1.0.0 is installed from the `21-breakincode` marketplace.
2. All 5 user commands below work against the LifeOS vault.
3. The vault holds no excalidraw skill, scripts, or hook. kepano's plugin is uninstalled.
4. The plugin holds no LifeOS paths. Every vault opinion lives in the vault config file.

## Philosophy

1. The `obsidian` CLI is the single source of truth for vault operations. The
   plugin never copies CLI flag lists. It points to `obsidian help <cmd>`.
2. Excalidraw is the drawing tool. No JSON Canvas support.
3. Each note type has one fixed format.
4. Tags come from one approved taxonomy. Tag drift gets an audit on demand.

## Plugin layout

```
obsidian-kit/
├─ .claude-plugin/plugin.json
├─ NOTICE                      kepano MIT notice for absorbed skills
├─ CHANGELOG.md
├─ skills/
│  ├─ create-excali/SKILL.md   user command
│  ├─ update-excali/SKILL.md   user command
│  ├─ format-note/SKILL.md     user command + auto while writing notes
│  ├─ migrate-notes/SKILL.md   user command, disable-model-invocation: true
│  ├─ audit-tags/SKILL.md      user command, disable-model-invocation: true
│  ├─ obsidian-markdown/       hidden, user-invocable: false (from kepano)
│  └─ obsidian-bases/          hidden, user-invocable: false (from kepano)
├─ references/
│  ├─ excali-principles.md     9 principles, shared by create/update-excali
│  ├─ excali-kit.md            kit API (was references/kit.md)
│  ├─ excali-rubric.md         render rubric (was references/rubric.md)
│  ├─ note-formats.md          5 note-type formats
│  └─ visual-patterns.md       ASCII + callout rules (from note-visualizer)
├─ scripts/
│  ├─ common/vault.py          vault root, config load, Obsidian-running check
│  ├─ excalidraw/              build, lint, render, ea_bridge, style_kit*.js, tests
│  ├─ notes/                   infer_type.py, check_note.py, test_infer.py
│  └─ tags/                    scan.py, classify.py, apply.py, test_classify.py
└─ hooks/
   ├─ hooks.json
   ├─ session-primer.py        SessionStart
   ├─ excali-lint.sh           PostToolUse
   └─ remind-format.py         PostToolUse (replaces remind-visualize.py)
```

Every script path in a skill or hook uses `${CLAUDE_PLUGIN_ROOT}` (plugin rule 1).
No file references another plugin (plugin rule 2).

## Commands

| Command | Does |
|---|---|
| `/obsidian-kit:create-excali` | Plan, build, lint, and render a new drawing |
| `/obsidian-kit:update-excali` | Dump an existing drawing, keep all content and links, rebuild |
| `/obsidian-kit:format-note <path\|folder>` | Check notes against their `note-type` format, propose fixes |
| `/obsidian-kit:migrate-notes` | One time: set `note-type` and rename map notes |
| `/obsidian-kit:audit-tags` | Scan, classify, plan, apply tag refactors |

`create-excali` and `update-excali` hold only their own workflow. Both read
`references/excali-principles.md` and use the same scripts. The workflow and
principles are today's `excalidraw-refine` skill, unchanged.

## Session primer hook

`session-primer.py` runs at SessionStart. It exits silently unless the
working directory contains `.obsidian/`. Otherwise it prints about 8 lines:

- The `obsidian` CLI is the source of truth. If unsure or a command fails, run `obsidian help <cmd>`.
- The category table below.
- Before a bulk write, list the files. Undo is `obsidian history:restore`.
- For a URL, prefer `defuddle parse <url> --md` over WebFetch.

```
read      read, search, search:context, outline, links, backlinks, tags, properties
write     create, append, prepend, property:set, property:remove
organize  move, rename, delete (moves to trash; wikilinks auto-update)
recover   history, history:read, history:restore, sync:history, sync:restore, diff
inspect   orphans, deadends, unresolved, vault, file, wordcount
develop   eval, dev:screenshot, dev:errors, dev:console, plugin:reload
```

kepano's `obsidian-cli` and `defuddle` skills are not absorbed. The primer
replaces them. `knap` and `json-canvas` are dropped.

## Vault config

The plugin reads `.obsidian-kit.json` at the vault root. If the file is
missing, each command stops and prints the path to create.

```json
{
  "taxonomyPath": "03Resource/About/tag-taxonomy.md",
  "noteFormatFolders": [
    "03Resource/Zettelkasten",
    "01Project/Appier/Notes",
    "01Project/Leetcode"
  ],
  "excludedPaths": [
    "01Project/Appier/Credentials",
    "03Resource/Credentials",
    "04Archive"
  ],
  "typeFolders": {
    "03Resource/Zettelkasten/Permanent": "concept",
    "03Resource/Zettelkasten/Literature": "literature",
    "03Resource/Zettelkasten/Fleeting": "fleeting"
  }
}
```

Every scan skips `excludedPaths`. Scripts never read those folders.

## Note types

Each in-scope note gets `note-type:` in frontmatter. The key is `note-type`,
not `type`, because Appier notes already use `type:` for other values.

All types share line 1: inline tags from the taxonomy.

| note-type | Name | Required body |
|---|---|---|
| `map` | `00__map__<topic>.md` in its series folder | bold claim, overview ASCII diagram, ordered `[[links]]` with a one-line gloss |
| `concept` | free | title, bold one-sentence claim, a diagram for an idea with shape, bullets, `Related:`, `Sources:`. One screen, about 40 lines |
| `takeaway` | `NN__<slug>.md` (tens = section, units = step) | same as concept, plus `> [!example] From this session` and a link back to the map |
| `literature` | free | `> Link: <url>`, title, bold claim. No line budget. For a URL source, the body comes from defuddle |
| `fleeting` | free | tags and title only |

The ASCII and callout rules in `references/visual-patterns.md` apply to
concept, takeaway, and map notes.

### format-note

Two modes:

1. Inline: when Claude writes a note inside `noteFormatFolders`, it picks the
   type, writes to that format, and sets `note-type`. This replaces the
   visualize skill's proactive trigger.
2. Check: `check_note.py` reports each failing rule per note. Claude proposes
   fixes. The user approves before any write.

`remind-format.py` fires after Edit or Write on a `.md` inside
`noteFormatFolders` and reminds Claude to apply format-note.

### migrate-notes

Runs once, as plan, approve, apply.

`infer_type.py` applies these rules in order. The first match wins:

1. Name matches `00__map__*`, `_index*`, `*__index`, `*MOC*`, or `*MoC*` → `map`.
2. Name starts with two digits and `__`, and a map note sits in the same folder → `takeaway`.
3. The path is under a `typeFolders` key → that type.
4. No match → unset. The plan lists the note for the user to decide.

The plan is one table: path, inferred type, matched rule, and the new name for
each map. Map notes are renamed to `00__map__<topic>.md` with `obsidian move`,
so wikilinks update. The topic is the series folder name. The user edits the
plan, then approves it once. The apply step sets `note-type` with
`obsidian property:set`.

## Tags

### Taxonomy file

A markdown file at `taxonomyPath` with two tables:

- `## Allowed`: `| tag | meaning |`
- `## Merged`: `| old | new | date |`

`lc-tag-taxonomy.md` stays in the vault. The taxonomy file links to it for
`#lc/*` and does not copy it.

When Claude writes a note in `noteFormatFolders`, it uses only Allowed tags.
If no tag fits, it proposes a new tag and asks. It never adds a tag silently.

### audit-tags

```
1 scan      obsidian tags counts, obsidian tag name=<t> verbose
2 classify  false tag | merged-but-back | duplicate | typo | singleton | off-taxonomy
3 plan      table: old → new | "code" | "keep", affected file count
            the user edits and approves the plan once
4 apply     rewrite inline tags and frontmatter tags; false tags get
            wrapped in backticks (text stays, tag goes)
5 update    add merges to ## Merged, new tags to ## Allowed
```

`classify.py` rules:

- False tag: starts with a digit, is a 6- or 7-character hex string, or contains CJK punctuation.
- Merged-but-back: the tag appears in the `## Merged` old column.
- Duplicate: same parent, and one leaf is a prefix that covers at least half of the other (`network`, `networking`).
- Typo: edit distance ≤ 2 from an Allowed tag.
- Duplicate and typo results are suggestions. Nothing merges without the plan approval.

## Safety

- Every script starts with `obsidian version`. If Obsidian is not running, it
  exits with one line: "Open Obsidian, then run again."
- Every bulk write follows plan, approve, apply. The apply step writes a
  change log to the session scratchpad. The log lists every changed path and
  its `obsidian history:restore` command.
- `create-excali` never overwrites. `update-excali` asks before `--overwrite`
  on a drawing that Claude did not create in the session.

## Tests

- `scripts/excalidraw/test_lint.py` moves unchanged and must pass.
- `scripts/tags/test_classify.py`: `#0c8599`, `#4f67687`, `#13，我卻把`, `#1-`,
  `db`/`database`, `system-deisgn`/`system-design`.
- `scripts/notes/test_infer.py`: one case per rule, using real vault paths
  such as `Literature/GoConcurrencyOOM/00__map__go__concurrency__OOM.md` and
  `Literature/GoConcurrencyOOM/31__semaphore__Weighted__internals.md`.
- Smoke test before cutover: build one drawing with `create-excali` and run
  `audit-tags` to the plan step only.

## Migration and cutover

In `PersonalPlugins`:

1. `git mv note-visualizer obsidian-kit`. Set version 1.0.0 in `plugin.json`,
   `marketplace.json`, and `content/plugins.content.json` together.
2. Copy kepano's `obsidian-markdown` and `obsidian-bases` skills. Add `NOTICE`.
3. Move the excalidraw skill, references, scripts, and hook. Rewrite paths to
   `${CLAUDE_PLUGIN_ROOT}`.
4. Add note-format, migrate-notes, audit-tags, and the primer hook.
5. Run `./scripts/cicd.sh GEN`.

In LifeOS, after the smoke test passes, each step needs user approval:

1. Create `.obsidian-kit.json` and the taxonomy file.
2. Remove `.claude/skills/excalidraw-refine`, the skill and scripts under
   `03Resource/symlink/claude/`, `hooks/excalidraw-lint.sh`, and its
   `settings.local.json` entry.
3. Uninstall kepano's `obsidian` plugin and `note-visualizer`.
4. Update the CLAUDE.md task routing row `obsidian:*` to `obsidian-kit:*`.
5. Update the `excalidraw-refine-plugin-plan` memory.

## Out of scope

- Broken links, orphans, and dead ends. The vault's `vault-auditor` agent owns them.
- Journal, Goals, Writing, and handover notes. Other skills own their formats.
- Scheduled or background runs. Every command runs on demand.
