# cc-plugins — Claude Code plugin marketplace

Monorepo of Claude Code plugins published via `.claude-plugin/marketplace.json`
(marketplace `21-breakincode`). Each plugin lives in its own top-level directory
with its own `CLAUDE.md`.

## Standards

- General: `~/.claude/rules/dev-principles.md`, `~/.claude/rules/coding-style.md`, `~/.claude/rules/git-workflow.md`
- Plugin development (sourcing, cross-plugin boundaries, generated docs, versioning) — **follow for any plugin change:**

@.claude/rules/plugin-rules.md

## Docs are generated

`CATALOG.md`, per-plugin `README.md`, and `site/*` are generated from
`.claude-plugin/marketplace.json` + `content/plugins.content.json`. Run
`./scripts/cicd.sh GEN` (or rely on the pre-commit hook) — never hand-edit them.
