# cc-plugins — Claude Code plugin marketplace

Monorepo of Claude Code plugins published via `.claude-plugin/marketplace.json`
(marketplace `21-breakincode`). Each plugin lives in its own top-level directory
with its own `CLAUDE.md`.

## Standards

- General: `~/.claude/rules/dev-principles.md`, `~/.claude/rules/coding-style.md`, `~/.claude/rules/git-workflow.md`
- Plugin development (sourcing, cross-plugin boundaries, generated docs, versioning) — **follow for any plugin change:**
- Skill authoring (invocation, information hierarchy, leading words, failure modes) — **follow for any skill change:**

@.claude/rules/plugin-rules.md
@.claude/rules/writing-great-skills.md

## Docs are generated

`CATALOG.md`, per-plugin `README.md`, and `site/*` are generated from
`.claude-plugin/marketplace.json` + `content/plugins.content.json`. Run
`./scripts/cicd.sh GEN` (or rely on the pre-commit hook) — never hand-edit them.

Edit/Write on `CATALOG.md`, `*/README.md`, and `site/data/plugins.json` is
mechanically denied (`.claude/settings.json`). `site/*.html` IS hand-editable —
but GEN owns its `?v=` asset stamps and the plugin count. Repo harness notes:
`.claude/docs/diagnosis-plugins-2026-07-05.md`.
