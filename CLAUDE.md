# cc-plugins — Claude Code plugin marketplace

Monorepo of Claude Code plugins published via `.claude-plugin/marketplace.json`
(marketplace `21-breakincode`). Each plugin lives in its own top-level directory
with its own `CLAUDE.md`.

## Standards

- General: `~/.claude/rules/dev-principles.md`, `~/.claude/rules/coding-style.md`, `~/.claude/rules/git-workflow.md`
- Plugin development (sourcing, cross-plugin boundaries, generated docs, versioning) — **follow for any plugin change:**
- Skill authoring (invocation, information hierarchy, leading words, failure modes) — **follow for any skill change:**
  `.claude/rules/writing-great-skills.md`. When you read a `skills/` or
  `commands/` file, it loads. When you create a new skill, read it first.

@.claude/rules/plugin-rules.md

## Docs are generated

Edit/Write on `CATALOG.md`, `*/README.md`, and `site/data/plugins.json` is
mechanically denied (`.claude/settings.json`). `site/*.html` are hand-authored
redirect shells to 21-breakincode.com/{lang}/plugins/. Repo harness notes:
`.claude/docs/diagnosis-plugins-2026-07-05.md`.

`site/data/plugins.json` on `main` is a public contract: the portfolio
(21-breakincode.com/{lang}/plugins/) fetches it by that exact path at build
time, and `.github/workflows/rebuild-portfolio.yml` triggers that build when it
changes. Moving or reshaping the file breaks the portfolio build.
