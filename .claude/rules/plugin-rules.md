# Plugin Development Rules

Conventions for every plugin in this marketplace repo (`21-BreakinCode/cc-plugins`).
Each plugin lives under its own top-level `<plugin>/` directory. Follow these for
any plugin change.

## 1. Reference bundled files via `${CLAUDE_PLUGIN_ROOT}` (CRITICAL)

A plugin's commands, agents, and skills MUST locate their own bundled files
(`lib/`, `templates/`, `skills/`, …) through the `${CLAUDE_PLUGIN_ROOT}`
environment variable — never by searching the plugins directory.

```
# Commands / agents / skills (.md bash blocks)
WRONG:   source "$(find ~/.claude/plugins -path '*/myplugin/lib/foo.sh' -print -quit)"
CORRECT: source "${CLAUDE_PLUGIN_ROOT}/lib/foo.sh"
```

When one lib sources a **sibling lib**, resolve relative to the file itself —
`${CLAUDE_PLUGIN_ROOT}` is only guaranteed in command/agent/skill execution, not
inside an already-sourced shell file:

```
# Inside lib/*.sh
WRONG:   source "$(find ~/.claude/plugins -path '*/myplugin/lib/common.sh' -print -quit)"
CORRECT: source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

Rationale: `find ~/.claude/plugins` is fragile — it breaks when the install path
changes, when the plugin is symlinked, and (worst) when it points at a *different*
plugin that may not be installed. `${CLAUDE_PLUGIN_ROOT}` is the documented,
portable path Claude Code injects for plugin execution.

## 2. Never reach across plugin boundaries (CRITICAL)

A plugin MUST NOT source another plugin's libs, dispatch another plugin's agents,
or depend on another plugin's skills. Claude Code has **no plugin dependency
mechanism**, so a cross-plugin reference is silently fragile — it works only while
the other plugin happens to be installed at the expected path.

If two plugins need the same logic: merge them into one plugin, or duplicate the
small piece intentionally. Never bridge plugins with a `find` lookup.

## 3. Generated docs have a single source of truth

`CATALOG.md`, every `<plugin>/README.md`, and `site/*` are GENERATED. Never edit
them by hand.

- Edit the source of truth: `.claude-plugin/marketplace.json` (manifest) and
  `content/plugins.content.json` (prose: tagline, summary, category, config).
- Regenerate with `./scripts/cicd.sh GEN`; the pre-commit hook runs it too.
- `marketplace.json` and `content/plugins.content.json` MUST stay in lockstep —
  every marketplace plugin needs a matching content entry, or GEN throws.
- Commands and skills are harvested automatically from each plugin folder — do
  NOT list them in `content/plugins.content.json`. Commands whose description is
  marked `[DEPRECATED]` are excluded from the catalog automatically.

## 4. Version every shipped change

When a plugin's behavior changes, bump its version in BOTH
`.claude-plugin/marketplace.json` and `<plugin>/.claude-plugin/plugin.json`
(keep the two equal). Marketplaces compare versions to offer `plugin update`, so
an un-bumped change never reaches installed users.

## Pre-commit checklist for a plugin change

- [ ] No `find ~/.claude/plugins` in any command/agent/skill/lib
- [ ] No reference to another plugin's files, agents, or skills
- [ ] `${CLAUDE_PLUGIN_ROOT}` for bundled files; `$(dirname "${BASH_SOURCE[0]}")` for lib→sibling
- [ ] Version bumped in `marketplace.json` + the plugin's `plugin.json` (if behavior changed)
- [ ] `./scripts/cicd.sh VERIFY` passes (tests + generated docs in sync)
